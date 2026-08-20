import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class AppStore: ObservableObject, NtfyClientDelegate {
    static let shared = AppStore()

    @Published var items: [InboxItem] = []
    @Published var connection: ConnectionState = .idle
    @Published var muted = false
    @Published var serverURL: String
    @Published var topicsText: String
    @Published var token: String
    @Published var username: String
    @Published var password: String
    @Published var minPriority: Int
    @Published var soundEnabled: Bool
    @Published var launchAtLogin: Bool
    @Published var settingsOpen = false
    @Published var authProbe: String = ""
    @Published var collapsedTopics: Set<String> = []

    let notifications = NotificationService()
    private let client = NtfyClient()
    private var live = false
    private var startedAt = Date()
    private var reconnectHold: Task<Void, Never>?
    private var lastSeenID: String
    private var lastSeenTime: Int
    private var wakeObserver: NSObjectProtocol?
    private let defaults = UserDefaults.standard
    private let historyURL: URL
    private let deletedURL: URL
    private var deletedIDs: [String] = []

    var unreadCount: Int { items.filter(\.unread).count }

    var groupedItems: [(topic: String, items: [InboxItem])] {
        var order: [String] = []
        var buckets: [String: [InboxItem]] = [:]
        for item in items {
            if buckets[item.topic] == nil {
                order.append(item.topic)
                buckets[item.topic] = []
            }
            buckets[item.topic, default: []].append(item)
        }
        return order.map { (topic: $0, items: buckets[$0] ?? []) }
    }

    var topics: [String] {
        topicsText
            .split { $0 == "," || $0 == "\n" || $0 == " " }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var needsSetup: Bool {
        serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || topics.isEmpty
    }

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NtfyBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        historyURL = support.appendingPathComponent("history.json")
        deletedURL = support.appendingPathComponent("deleted.json")

        serverURL = defaults.string(forKey: "serverURL") ?? KaiserlichDefaults.serverURL
        topicsText = defaults.string(forKey: "topics") ?? KaiserlichDefaults.topics.joined(separator: "\n")
        username = defaults.string(forKey: "username") ?? ""
        minPriority = defaults.object(forKey: "minPriority") as? Int ?? 2
        soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        muted = defaults.bool(forKey: "muted")
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        collapsedTopics = Set(defaults.stringArray(forKey: "collapsedTopics") ?? [])
        token = Keychain.get(account: "token")
        password = Keychain.get(account: "password")
        lastSeenID = defaults.string(forKey: "lastSeenID") ?? ""
        lastSeenTime = defaults.object(forKey: "lastSeenTime") as? Int ?? 0
        items = Self.load(historyURL)
        deletedIDs = Self.loadDeleted(deletedURL)
        let blocked = Set(deletedIDs)
        items.removeAll { blocked.contains($0.id) }
        if lastSeenID.isEmpty { lastSeenID = items.first?.id ?? "" }
        if lastSeenTime == 0 {
            lastSeenTime = items.first?.event.time ?? Int(Date().timeIntervalSince1970)
        }
        client.delegate = self
        notifications.onOpen = { [weak self] item in self?.open(item) }
        notifications.onAction = { [weak self] item, action in self?.run(action, for: item) }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWake()
            }
        }
    }

    func start() {
        notifications.request()
        startedAt = Date()
        applyLoginItem()
        reconnect()
        if !hasAuth {
            settingsOpen = true
        }
    }

    func persistSettings() {
        defaults.set(serverURL, forKey: "serverURL")
        defaults.set(topicsText, forKey: "topics")
        defaults.set(username, forKey: "username")
        defaults.set(minPriority, forKey: "minPriority")
        defaults.set(soundEnabled, forKey: "soundEnabled")
        defaults.set(muted, forKey: "muted")
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        defaults.set(Array(collapsedTopics), forKey: "collapsedTopics")
        Keychain.set(token, account: "token")
        Keychain.set(password, account: "password")
        applyLoginItem()
    }

    var hasAuth: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func save() {
        persistSettings()
        Task { await probeThenConnect() }
    }

    func probeThenConnect() async {
        if let error = await probeAuth() {
            authProbe = error
            connection = .failed(error)
            return
        }
        authProbe = "Signed in"
        reconnect()
    }

    func reconnect() {
        live = false
        client.stop()
        guard !needsSetup else {
            connection = .failed("Add a server and topics")
            return
        }
        guard hasAuth else {
            connection = .failed("Enter username and password")
            return
        }
        guard let url = URL(string: normalizedServer) else {
            connection = .failed("Bad server URL")
            return
        }
        client.start(
            NtfyClient.Config(
                serverURL: url,
                topics: topics,
                token: token.trimmingCharacters(in: .whitespacesAndNewlines),
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                since: catchUpSince
            )
        )
    }

    func authorizationHeader() -> String? {
        let tok = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tok.isEmpty { return "Bearer \(tok)" }
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty else { return nil }
        let raw = "\(user):\(password)"
        return "Basic \(Data(raw.utf8).base64EncodedString())"
    }

    func probeAuth() async -> String? {
        guard hasAuth else { return "Enter username and password" }
        guard let topic = topics.first else { return "Add a topic" }
        guard let url = URL(string: "\(normalizedServer)/\(topic)/json?poll=1") else {
            return "Bad server URL"
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        if let auth = authorizationHeader() {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        do {
            let session = URLSession(configuration: .ephemeral)
            let (_, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 401 || code == 403 { return "Wrong username or password" }
            if code >= 400 { return "Server HTTP \(code)" }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func ntfyDidReceive(_ event: NtfyEvent) {
        switch event.event {
        case "open":
            live = true
        case "message":
            ingest(event)
        case "message_delete":
            items.removeAll { $0.id == event.id }
            persist()
        case "message_clear":
            items.removeAll { $0.topic == event.topic }
            persist()
        default:
            break
        }
    }

    func ntfyDidChangeState(_ state: ConnectionState) {
        switch state {
        case .connected:
            reconnectHold?.cancel()
            reconnectHold = nil
            live = true
            connection = .connected
        case .connecting, .reconnecting:
            live = false
            holdReconnect(state)
        default:
            reconnectHold?.cancel()
            reconnectHold = nil
            live = false
            connection = state
        }
    }

    private func holdReconnect(_ state: ConnectionState) {
        if connection == .connected {
            reconnectHold?.cancel()
            reconnectHold = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                if case .connected = self.connection { return }
                self.connection = state
            }
            return
        }
        connection = state
    }

    func markAllRead() {
        items = items.map { item in
            var copy = item
            copy.unread = false
            return copy
        }
        persist()
        NSApp.dockTile.badgeLabel = nil
    }

    func markRead(_ id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].unread = false
        persist()
    }

    func clear() {
        rememberDeleted(items.map(\.id))
        items = []
        persist()
        notifications.dismissAll()
    }

    func remove(_ id: String) {
        items.removeAll { $0.id == id }
        rememberDeleted([id])
        persist()
        notifications.dismiss(id)
    }

    func removeTopic(_ topic: String) {
        let ids = items.filter { $0.topic == topic }.map(\.id)
        items.removeAll { $0.topic == topic }
        rememberDeleted(ids)
        persist()
        ids.forEach { notifications.dismiss($0) }
    }

    func toggleTopic(_ topic: String) {
        if collapsedTopics.contains(topic) {
            collapsedTopics.remove(topic)
        } else {
            collapsedTopics.insert(topic)
        }
        persistSettings()
    }

    func isCollapsed(_ topic: String) -> Bool {
        collapsedTopics.contains(topic)
    }

    func item(id: String) -> InboxItem? {
        items.first { $0.id == id }
    }

    func open(_ item: InboxItem) {
        markRead(item.id)
        if let click = item.event.click, let url = URL(string: click) {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "\(normalizedServer)/\(item.topic)") {
            NSWorkspace.shared.open(url)
        }
    }

    func run(_ action: NtfyAction, for item: InboxItem) {
        markRead(item.id)
        switch action.action {
        case "view":
            if let raw = action.url, let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
            }
        case "http":
            Task { await http(action) }
        case "copy":
            let paste = action.value ?? action.url ?? ""
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(paste, forType: .string)
        default:
            break
        }
    }

    func openWeb() {
        if let url = URL(string: normalizedServer) {
            NSWorkspace.shared.open(url)
        }
    }

    func sendTest() async {
        persistSettings()
        guard hasAuth else {
            authProbe = "Enter username and password"
            return
        }
        guard let topic = topics.first else {
            authProbe = "Add a topic"
            return
        }
        guard let url = URL(string: "\(normalizedServer)/\(topic)") else {
            authProbe = "Bad server URL"
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data("If you see this in the menu bar, NtfyBar is live.".utf8)
        request.setValue("NtfyBar test", forHTTPHeaderField: "Title")
        request.setValue("4", forHTTPHeaderField: "Priority")
        request.setValue("white_check_mark,bell", forHTTPHeaderField: "Tags")
        if let auth = authorizationHeader() {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        do {
            let (_, response) = try await URLSession(configuration: .ephemeral).data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code >= 400 {
                authProbe = "Test publish HTTP \(code)"
            } else {
                authProbe = "Test sent to \(topic) — watch the bell"
            }
        } catch {
            authProbe = error.localizedDescription
        }
    }

    func restoreKaiserlichTopics() {
        topicsText = KaiserlichDefaults.topics.joined(separator: "\n")
        if serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            serverURL = KaiserlichDefaults.serverURL
        }
    }

    func handleWake() {
        Log.write("wake — reconnecting")
        reconnect()
    }

    private var catchUpSince: String {
        if !lastSeenID.isEmpty { return lastSeenID }
        if lastSeenTime > 0 { return String(lastSeenTime) }
        return "12h"
    }

    var normalizedServer: String {
        var value = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasSuffix("/") { value.removeLast() }
        if !value.contains("://") { value = "https://\(value)" }
        return value
    }

    private func ingest(_ event: NtfyEvent) {
        guard !deletedIDs.contains(event.id) else {
            noteSeen(event)
            return
        }
        guard !items.contains(where: { $0.id == event.id }) else {
            noteSeen(event)
            return
        }
        let item = InboxItem(id: event.id, event: event, unread: true, receivedAt: Date())
        items.insert(item, at: 0)
        if items.count > 200 { items = Array(items.prefix(200)) }
        persist()

        let isCatchUp = event.time >= lastSeenTime
        noteSeen(event)
        let shouldBanner = !muted && event.resolvedPriority >= minPriority && isCatchUp
        if shouldBanner {
            notifications.deliver(item, sound: soundEnabled)
        }
    }

    private func noteSeen(_ event: NtfyEvent) {
        if event.time > lastSeenTime || (event.time == lastSeenTime && event.id != lastSeenID) {
            lastSeenTime = event.time
            lastSeenID = event.id
            defaults.set(lastSeenID, forKey: "lastSeenID")
            defaults.set(lastSeenTime, forKey: "lastSeenTime")
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: historyURL, options: .atomic)
            let deleted = try JSONEncoder().encode(deletedIDs)
            try deleted.write(to: deletedURL, options: .atomic)
        } catch {
            NSLog("NtfyBar: history write failed: \(error)")
        }
    }

    private func rememberDeleted(_ ids: [String]) {
        deletedIDs.insert(contentsOf: ids, at: 0)
        var seen = Set<String>()
        deletedIDs = deletedIDs.filter { seen.insert($0).inserted }
        if deletedIDs.count > 500 { deletedIDs = Array(deletedIDs.prefix(500)) }
    }

    private static func load(_ url: URL) -> [InboxItem] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([InboxItem].self, from: data)) ?? []
    }

    private static func loadDeleted(_ url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private func applyLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("NtfyBar: login item failed: \(error)")
            }
        }
    }

    private func http(_ action: NtfyAction) async {
        guard let raw = action.url, let url = URL(string: raw) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = (action.method ?? "POST").uppercased()
        if let body = action.body { request.httpBody = Data(body.utf8) }
        action.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        _ = try? await URLSession.shared.data(for: request)
    }
}
