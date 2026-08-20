import AppKit
import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    var onOpen: ((InboxItem) -> Void)?
    var onAction: ((InboxItem, NtfyAction) -> Void)?

    func request() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        registerCategories()
    }

    func dismiss(_ id: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }

    func dismissAll() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func deliver(_ item: InboxItem, sound: Bool) {
        let event = item.event
        let content = UNMutableNotificationContent()
        content.title = event.displayTitle
        content.subtitle = event.topic
        content.body = event.displayBody
        content.userInfo = ["id": item.id]
        content.threadIdentifier = event.topic
        content.categoryIdentifier = "ntfy.message"
        content.interruptionLevel = interruption(event.resolvedPriority)
        if sound, event.resolvedPriority >= 3 {
            content.sound = .default
        }

        var actions: [UNNotificationAction] = []
        for (index, action) in (event.actions ?? []).prefix(3).enumerated() {
            actions.append(
                UNNotificationAction(
                    identifier: "action.\(index)",
                    title: action.label,
                    options: action.action == "view" ? [.foreground] : []
                )
            )
        }
        if !actions.isEmpty {
            let category = UNNotificationCategory(
                identifier: "ntfy.message.\(item.id)",
                actions: actions,
                intentIdentifiers: []
            )
            UNUserNotificationCenter.current().setNotificationCategories([category])
            content.categoryIdentifier = category.identifier
        }

        let request = UNNotificationRequest(identifier: item.id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        let actionId = response.actionIdentifier
        Task { @MainActor in
            defer { completionHandler() }
            guard let item = AppStore.shared.item(id: id) else { return }
            if actionId.hasPrefix("action.") {
                let index = Int(actionId.dropFirst("action.".count)) ?? 0
                let actions = item.event.actions ?? []
                if index >= 0, index < actions.count {
                    self.onAction?(item, actions[index])
                    return
                }
            }
            self.onOpen?(item)
        }
    }

    private func registerCategories() {
        let category = UNNotificationCategory(identifier: "ntfy.message", actions: [], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func interruption(_ priority: Int) -> UNNotificationInterruptionLevel {
        switch priority {
        case 4, 5: return .timeSensitive
        case 1, 2: return .passive
        default: return .active
        }
    }
}
