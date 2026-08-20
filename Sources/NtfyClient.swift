import Foundation

@MainActor
protocol NtfyClientDelegate: AnyObject {
    func ntfyDidReceive(_ event: NtfyEvent)
    func ntfyDidChangeState(_ state: ConnectionState)
}

final class NtfyClient {
    weak var delegate: NtfyClientDelegate?

    private var streamTask: Task<Void, Never>?
    private var session: URLSession
    private var attempt = 0
    private var stopped = true
    private var config: Config?

    struct Config {
        var serverURL: URL
        var topics: [String]
        var token: String
        var username: String
        var password: String
        var since: String?
    }

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 600
        cfg.timeoutIntervalForResource = 60 * 60 * 24 * 7
        cfg.waitsForConnectivity = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: cfg)
    }

    func start(_ config: Config) {
        stopped = false
        self.config = config
        attempt = 0
        connect()
    }

    func stop() {
        stopped = true
        streamTask?.cancel()
        streamTask = nil
        emit(.idle)
    }

    private func connect() {
        streamTask?.cancel()
        guard !stopped, let config else { return }
        guard !config.topics.isEmpty else {
            emit(.failed("No topics"))
            return
        }
        guard let url = makeURL(config) else {
            emit(.failed("Bad server URL"))
            return
        }
        if attempt == 0 { emit(.connecting) }
        streamTask = Task { [weak self] in
            await self?.run(url: url, config: config)
        }
    }

    private func run(url: URL, config: Config) async {
        var request = URLRequest(url: url)
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
        if let auth = authorization(config) {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }

        do {
            let (bytes, response) = try await session.bytes(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 401 || http.statusCode == 403 {
                    failAndRetry("Wrong username or password")
                    return
                }
                if http.statusCode >= 400 {
                    failAndRetry("Server HTTP \(http.statusCode)")
                    return
                }
            }
            attempt = 0
            emit(.connected)
            Log.write("connected \(url.path)")
            for try await line in bytes.lines {
                if Task.isCancelled || stopped { return }
                handle(line)
            }
            failAndRetry("Stream closed")
        } catch is CancellationError {
            return
        } catch {
            if stopped || Task.isCancelled { return }
            failAndRetry(error.localizedDescription)
        }
    }

    private func handle(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        do {
            let event = try JSONDecoder().decode(NtfyEvent.self, from: data)
            Task { @MainActor [weak self] in
                self?.delegate?.ntfyDidReceive(event)
            }
        } catch {
            Log.write("decode failed: \(error) line=\(trimmed.prefix(200))")
        }
    }

    private func failAndRetry(_ reason: String) {
        guard !stopped else { return }
        Log.write("retry: \(reason)")
        let delay = min(15.0, pow(2.0, Double(min(attempt, 4))))
        if attempt == 0 { emit(.failed(reason)) }
        attempt += 1
        if attempt >= 2 { emit(.reconnecting) }
        streamTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            self?.connect()
        }
    }

    private func emit(_ state: ConnectionState) {
        Task { @MainActor [weak self] in
            self?.delegate?.ntfyDidChangeState(state)
        }
    }

    private func makeURL(_ config: Config) -> URL? {
        var components = URLComponents(url: config.serverURL, resolvingAgainstBaseURL: false)
        let topics = config.topics.map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
        components?.path = "/" + topics.joined(separator: ",") + "/json"
        components?.queryItems = [
            URLQueryItem(name: "since", value: config.since?.isEmpty == false ? config.since : "10m")
        ]
        return components?.url
    }

    private func authorization(_ config: Config) -> String? {
        if !config.token.isEmpty { return "Bearer \(config.token)" }
        if !config.username.isEmpty {
            let raw = "\(config.username):\(config.password)"
            return "Basic \(Data(raw.utf8).base64EncodedString())"
        }
        return nil
    }
}

enum Log {
    static func write(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NtfyBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("client.log")
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: url)
        }
    }
}
