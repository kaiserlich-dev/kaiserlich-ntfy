import AppKit
import Combine
import SwiftUI

@main
struct NtfyBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    private let store = AppStore.shared
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)
        store.start()
        setupStatusItem()
        setupPopover()
        bind()
        if store.settingsOpen {
            showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func showSettings() {
        if settingsWindow == nil {
            let root = SettingsView().environmentObject(store)
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "ntfy"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 480, height: 620))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        store.settingsOpen = true
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            stopMonitor()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            startMonitor()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        statusItem.button?.toolTip = "ntfy"
        renderIcon()
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: InboxView().environmentObject(store)
        )
    }

    private func bind() {
        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.renderIcon() }
            }
            .store(in: &cancellables)
    }

    private func renderIcon() {
        let unread = store.unreadCount
        let connected = store.connection == .connected
        let muted = store.muted
        statusItem.button?.image = StatusIcon.image(unread: unread, connected: connected, muted: muted)
        statusItem.button?.image?.isTemplate = unread == 0
        statusItem.button?.appearsDisabled = !connected && unread == 0
        statusItem.button?.toolTip = tooltip(unread: unread, connected: connected)
    }

    private func tooltip(unread: Int, connected: Bool) -> String {
        let state = store.connection.label
        if unread == 0 { return "ntfy — \(state)" }
        return "ntfy — \(unread) unread — \(state)"
    }

    private func startMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
            self?.stopMonitor()
        }
    }

    private func stopMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}

enum StatusIcon {
    static func image(unread: Int, connected: Bool, muted: Bool) -> NSImage {
        let size = NSSize(width: unread > 0 ? 26 : 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let symbolName = muted ? "bell.slash.fill" : "bell.fill"
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            guard let bell = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) else { return false }
            let bellRect = NSRect(x: 1, y: 1, width: 16, height: 16)
            if unread == 0 {
                NSColor.black.setFill()
            } else {
                (connected ? NSColor.labelColor : NSColor.secondaryLabelColor).setFill()
            }
            bell.draw(in: bellRect)

            if unread > 0 {
                let badge = NSRect(x: 13, y: 8, width: 13, height: 10)
                NSColor.systemOrange.setFill()
                NSBezierPath(roundedRect: badge, xRadius: 5, yRadius: 5).fill()
                let text = unread > 9 ? "9+" : "\(unread)"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .bold),
                    .foregroundColor: NSColor.black,
                ]
                let string = NSString(string: text)
                let textSize = string.size(withAttributes: attrs)
                string.draw(
                    at: NSPoint(
                        x: badge.midX - textSize.width / 2,
                        y: badge.midY - textSize.height / 2
                    ),
                    withAttributes: attrs
                )
            }
            return true
        }
        image.isTemplate = unread == 0
        return image
    }
}
