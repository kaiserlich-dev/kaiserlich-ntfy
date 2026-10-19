import Foundation
import SwiftUI

enum ConnectionState: Equatable {
    case idle
    case connecting
    case connected
    case reconnecting
    case failed(String)

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .connecting: return "Connecting"
        case .connected: return "Live"
        case .reconnecting: return "Reconnecting"
        case .failed(let reason): return reason
        }
    }
}

struct NtfyAction: Codable, Hashable {
    var action: String
    var label: String
    var url: String?
    var method: String?
    var body: String?
    var clear: Bool?
    var value: String?
    var headers: [String: String]?
}

struct NtfyAttachment: Codable, Hashable {
    var name: String
    var url: String
    var type: String?
    var size: Int?
}

struct NtfyEvent: Codable, Identifiable, Hashable {
    var id: String
    var time: Int
    var expires: Int?
    var event: String
    var topic: String
    var message: String?
    var title: String?
    var tags: [String]?
    var priority: Int?
    var click: String?
    var actions: [NtfyAction]?
    var attachment: NtfyAttachment?

    var resolvedPriority: Int { priority ?? 3 }

    var date: Date { Date(timeIntervalSince1970: TimeInterval(time)) }

    var displayTitle: String {
        let raw = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty { return topic }
        return EmojiTags.prefix(tags) + raw
    }

    var displayBody: String {
        let raw = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if title == nil || title?.isEmpty == true {
            return EmojiTags.prefix(tags) + raw
        }
        return raw
    }

    var nonEmojiTags: [String] {
        (tags ?? []).filter { EmojiTags.map[$0] == nil }
    }

    var clipboardText: String {
        var lines: [String] = []
        lines.append("topic: \(topic)")
        if let title, !title.isEmpty { lines.append("title: \(title)") }
        if resolvedPriority != 3 { lines.append("priority: \(resolvedPriority)") }
        if !nonEmojiTags.isEmpty { lines.append("tags: \(nonEmojiTags.joined(separator: ", "))") }
        let body = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !body.isEmpty {
            lines.append("")
            lines.append(body)
        }
        if let click, !click.isEmpty {
            lines.append("")
            lines.append(click)
        }
        return lines.joined(separator: "\n")
    }
}

struct InboxItem: Identifiable, Hashable, Codable {
    var id: String
    var event: NtfyEvent
    var unread: Bool
    var receivedAt: Date

    var topic: String { event.topic }
    var priority: Int { event.resolvedPriority }
}

enum EmojiTags {
    static let map: [String: String] = [
        "+1": "👍", "-1": "👎",
        "warning": "⚠️", "rotating_light": "🚨", "triangular_flag_on_post": "🚩",
        "skull": "💀", "no_entry": "⛔", "no_entry_sign": "🚫",
        "white_check_mark": "✅", "heavy_check_mark": "✔️", "x": "❌",
        "tada": "🎉", "partying_face": "🥳", "loudspeaker": "📢",
        "arrows_counterclockwise": "🔄", "battery": "🔋", "computer": "💻",
        "fire": "🔥", "boom": "💥", "bug": "🐛", "lock": "🔒",
        "unlock": "🔓", "key": "🔑", "email": "📧", "mailbox": "📫",
        "bell": "🔔", "mute": "🔇", "hourglass": "⏳", "stopwatch": "⏱️",
        "rocket": "🚀", "package": "📦", "hammer": "🔨", "wrench": "🔧",
        "gear": "⚙️", "memo": "📝", "chart_with_upwards_trend": "📈",
        "chart_with_downwards_trend": "📉", "moneybag": "💰",
        "facepalm": "🤦", "thinking": "🤔", "eyes": "👀",
        "wave": "👋", "ok_hand": "👌", "clap": "👏",
        "arrow_up": "⬆️", "arrow_down": "⬇️", "arrow_right": "➡️",
        "arrow_forward": "▶️", "zzz": "💤", "star": "⭐",
        "heart": "❤️", "broken_heart": "💔", "cd": "💿",
        "camera": "📷", "movie_camera": "🎥", "mag": "🔍",
    ]

    static func prefix(_ tags: [String]?) -> String {
        guard let tags, !tags.isEmpty else { return "" }
        let emojis = tags.compactMap { map[$0] }
        guard !emojis.isEmpty else { return "" }
        return emojis.joined() + " "
    }
}

enum AppDefaults {
    static let serverURL = ""
    static let topics: [String] = []
}

enum KaiserlichPreset {
    static let serverURL = "https://ntfy.kaiserlich.dev"
    static let topics = [
        "beszel",
        "big_alerts",
        "fr_alerts",
        "gutex_alerts",
        "homelab",
        "itmadesimple",
        "kaiserlich_alerts",
        "passag3-pilot-alerts",
        "uptime_alerts",
        "uv_alerts",
    ]
}

enum Palette {
    // System colours: follow light/dark mode and the user's accent colour.
    static let bg = Color.clear
    static let bgRaised = Color.primary.opacity(0.06)
    static let field = Color(nsColor: .textBackgroundColor)
    static let line = Color(nsColor: .separatorColor)
    static let text = Color.primary
    static let muted = Color.secondary
    static let amber = Color.accentColor
    static let copper = Color(nsColor: .systemOrange)
    static let live = Color(nsColor: .systemGreen)
    static let danger = Color(nsColor: .systemRed)

    // Only urgent messages get a colour; ntfy's default (3) and below stay plain.
    static func priority(_ value: Int) -> Color? {
        switch value {
        case 5: return danger
        case 4: return copper
        default: return nil
        }
    }
}

enum RelativeTime {
    static func string(from date: Date, now: Date = Date()) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 45 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3600)h" }
        if seconds < 604_800 { return "\(seconds / 86_400)d" }
        return "\(seconds / 604_800)w"
    }
}
