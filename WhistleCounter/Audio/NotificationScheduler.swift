import Foundation
import UserNotifications

/// Posts a local notification when the whistle target is reached,
/// so the user sees a banner / lockscreen alert even when the app is
/// backgrounded or the phone is locked.
@MainActor
final class NotificationScheduler {

    private enum Identifiers {
        static let targetReached = "whistle.targetReached"
    }

    /// Request permission. Safe to call on every launch — the system
    /// only shows the dialog once.
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Post an immediate notification for the current session.
    /// Shown as a banner + system sound when backgrounded, or in the
    /// Notification Center / lock screen otherwise. If the app is in
    /// the foreground we still fire it so the user sees feedback even
    /// if they've navigated away from the Counter tab.
    func postTargetReached(count: Int, recipeName: String?) {
        let content = UNMutableNotificationContent()
        content.title = recipeName ?? "Target reached"
        content.body = "\(count) whistles. Time to turn off the heat."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: Identifiers.targetReached,
            content: content,
            trigger: nil // immediate delivery
        )

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Clear any pending / delivered target-reached notifications.
    /// Called on stop / reset so a stale notification doesn't linger
    /// after the user has already acknowledged the alarm.
    func clearDelivered() {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [Identifiers.targetReached])
        center.removePendingNotificationRequests(withIdentifiers: [Identifiers.targetReached])
    }
}
