import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let dailyReminderIdentifier = "daily_checkin"
    private let aiAlertIdentifier = "ai_burnout_alert"

    private override init() {
        super.init()
    }

    func configure(pushEnabled: Bool) {
        center.delegate = self

        Task {
            _ = await reconcilePushPreference(pushEnabled: pushEnabled)
        }
    }
    
    func requestAuthorization() {
        Task {
            _ = await updatePushPreference(isEnabled: true)
        }
    }

    func updatePushPreference(isEnabled: Bool) async -> Bool {
        if !isEnabled {
            cancelDailyReminder()
            return false
        }

        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            scheduleDailyReminder()
            return true
        case .notDetermined:
            let granted = await requestSystemAuthorization()
            if granted {
                scheduleDailyReminder()
            } else {
                cancelDailyReminder()
            }
            return granted
        case .denied:
            cancelDailyReminder()
            return false
        @unknown default:
            cancelDailyReminder()
            return false
        }
    }

    func reconcilePushPreference(pushEnabled: Bool) async -> Bool {
        if !pushEnabled {
            cancelDailyReminder()
            return false
        }

        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            scheduleDailyReminder()
            return true
        case .notDetermined:
            cancelDailyReminder()
            return true
        case .denied:
            cancelDailyReminder()
            return false
        @unknown default:
            cancelDailyReminder()
            return false
        }
    }

    func isAuthorized() async -> Bool {
        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }
    
    func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time for your Evening Check-in"
        content.body = "Spend 30 seconds to log your vitals and protect your ELO streak! 🔥"
        content.sound = .default
        
        // Schedule for 8:00 PM every day
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderIdentifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling daily reminder: \(error.localizedDescription)")
            }
        }
    }
    
    func sendAIBurnoutAlert(riskLevel: String) {
        Task {
            guard await isAuthorized() else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "⚠️ High Burnout Risk Detected"
            content.body = "Ergon AI analyzed your latest HealthKit vitals. You are at \(riskLevel) risk. Tap to start a 60s breathing session to protect your streak."
            content.sound = .default

            // Trigger 3 seconds after the log is submitted so the user sees it immediately after closing the app/sheet
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            let request = UNNotificationRequest(identifier: aiAlertIdentifier, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    print("Error scheduling AI notification: \(error.localizedDescription)")
                }
            }
        }
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
    }
    
    func cancelAllReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier, aiAlertIdentifier])
    }

    private func requestSystemAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if granted {
                    print("Notification permission granted.")
                } else if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                }
                continuation.resume(returning: granted)
            }
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
