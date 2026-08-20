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

enum KaiserlichDefaults {
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
    static let bg = Color(red: 0.07, green: 0.07, blue: 0.06)
    static let bgRaised = Color(red: 0.11, green: 0.10, blue: 0.09)
    static let line = Color.white.opacity(0.08)
    static let text = Color(red: 0.93, green: 0.90, blue: 0.84)
    static let muted = Color(red: 0.62, green: 0.58, blue: 0.52)
    static let amber = Color(red: 0.91, green: 0.65, blue: 0.29)
    static let copper = Color(red: 0.72, green: 0.42, blue: 0.27)
    static let live = Color(red: 0.49, green: 0.72, blue: 0.49)
    static let danger = Color(red: 0.89, green: 0.29, blue: 0.29)

    static func priority(_ value: Int) -> Color {
        switch value {
        case 5: return danger
        case 4: return amber
        case 3: return copper
        case 2: return muted
        default: return muted.opacity(0.5)
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
