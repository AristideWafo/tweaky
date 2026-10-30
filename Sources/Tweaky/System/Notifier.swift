import AppKit
import UserNotifications

/// Short system notifications for the instant correction, which has no panel to show messages in.
enum Notifier {
    static func post(_ body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else {
                Task { @MainActor in NSSound.beep() }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Tweaky"
            content.body = body
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}
