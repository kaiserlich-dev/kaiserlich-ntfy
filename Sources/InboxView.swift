import AppKit
import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var store: AppStore
    @State private var now = Date()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Palette.line)
            if store.items.isEmpty {
                empty
            } else {
                List {
                    ForEach(store.groupedItems, id: \.topic) { group in
                        TopicHeader(
                            topic: group.topic,
                            count: group.items.count,
                            unread: group.items.filter(\.unread).count,
                            expanded: !store.isCollapsed(group.topic)
                        ) {
                            store.removeTopic(group.topic)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Palette.bgRaised)
                        .listRowSeparatorTint(Palette.line)
                        .contentShape(Rectangle())
                        .onTapGesture { store.toggleTopic(group.topic) }
                        .contextMenu {
                            Button(store.isCollapsed(group.topic) ? "Expand" : "Collapse") {
                                store.toggleTopic(group.topic)
                            }
                            Button("Clear topic", role: .destructive) {
                                store.removeTopic(group.topic)
                            }
                        }

                        if !store.isCollapsed(group.topic) {
                            ForEach(group.items) { item in
                                MessageRow(item: item, now: now) {
                                    store.remove(item.id)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { store.open(item) }
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowBackground(item.unread ? Palette.amber.opacity(0.05) : Palette.bg)
                                .listRowSeparatorTint(Palette.line)
                                .contextMenu {
                                    Button("Open") { store.open(item) }
                                    Button("Remove", role: .destructive) { store.remove(item.id) }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.remove(item.id)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            Divider().overlay(Palette.line)
            footer
        }
        .frame(width: 380, height: 520)
        .background(Palette.bg)
        .onAppear {
            store.markAllRead()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.8), radius: 4)
            VStack(alignment: .leading, spacing: 1) {
                Text("NTFY")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Palette.text)
                Text(store.connection.label.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
            IconButton(system: store.muted ? "bell.slash.fill" : "bell.fill", active: store.muted) {
                store.muted.toggle()
                store.persistSettings()
            }
            IconButton(system: "gearshape") {
                AppDelegate.shared?.showSettings()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Palette.bgRaised)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Palette.amber.opacity(0.8))
            Text(emptyTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.text)
            Text(emptyBody)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button("Mark read") { store.markAllRead() }
                .buttonStyle(.plain)
            Button("Clear") { store.clear() }
                .buttonStyle(.plain)
            Spacer()
            Button("Web") { store.openWeb() }
                .buttonStyle(.plain)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(Palette.muted)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Palette.bgRaised)
    }

    private var statusColor: Color {
        switch store.connection {
        case .connected: return Palette.live
        case .connecting, .reconnecting: return Palette.amber
        case .failed: return Palette.danger
        case .idle: return Palette.muted
        }
    }

    private var emptyTitle: String {
        if store.needsSetup || !store.hasAuth {
            return "Waiting for credentials"
        }
        switch store.connection {
        case .failed: return "Not connected"
        case .connecting, .reconnecting: return "Listening…"
        default: return "Quiet"
        }
    }

    private var emptyBody: String {
        if !store.hasAuth {
            return "Open settings and enter your ntfy username and password"
        }
        if case .failed(let reason) = store.connection { return reason }
        return "New messages from your topics land here."
    }
}

struct MessageRow: View {
    let item: InboxItem
    let now: Date
    var onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Palette.priority(item.priority))
                .frame(width: 3)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.event.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .lineLimit(2)
                    Spacer()
                    Text(RelativeTime.string(from: item.event.date, now: now))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }
                if let message = item.event.message, !message.isEmpty, message != item.event.displayTitle {
                    Text(item.event.displayBody)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(3)
                }
                if !item.event.nonEmojiTags.isEmpty {
                    Text(item.event.nonEmojiTags.joined(separator: " · "))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.muted.opacity(0.8))
                        .lineLimit(1)
                }
            }
            if item.unread {
                Circle()
                    .fill(Palette.amber)
                    .frame(width: 6, height: 6)
                    .padding(.top, 6)
            }
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .help("Remove")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onHover { hovering = $0 }
    }
}

struct TopicHeader: View {
    let topic: String
    let count: Int
    let unread: Int
    let expanded: Bool
    var onClear: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Palette.muted)
                .rotationEffect(.degrees(expanded ? 90 : 0))
                .frame(width: 12)
            Text(topic)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.amber)
                .lineLimit(1)
            Text("\(count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Palette.muted)
            Spacer()
            if unread > 0 {
                Text("\(unread)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.bg)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Palette.amber)
                    .clipShape(Capsule())
            }
            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .help("Clear topic")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onHover { hovering = $0 }
    }
}

struct IconButton: View {
    let system: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? Palette.amber : Palette.muted)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
