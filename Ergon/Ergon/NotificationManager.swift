import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
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
        let request = UNNotificationRequest(identifier: "daily_checkin", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendAIBurnoutAlert(riskLevel: String) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ High Burnout Risk Detected"
        content.body = "Ergon AI analyzed your latest HealthKit vitals. You are at \(riskLevel) risk. Tap to start a 60s breathing session to protect your streak."
        content.sound = .default
        
        // Trigger 3 seconds after the log is submitted so the user sees it immediately after closing the app/sheet
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling AI notification: \(error)")
            }
        }
    }
    
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
