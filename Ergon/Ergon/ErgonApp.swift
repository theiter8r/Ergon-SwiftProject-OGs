import SwiftUI
import Combine

@main
struct ErgonApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var eloViewModel = EloViewModel()

    init() {
        let pushNotificationsEnabled = (UserDefaults.standard.object(forKey: "pushNotifications") as? Bool) ?? true
        NotificationManager.shared.configure(pushEnabled: pushNotificationsEnabled)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(eloViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
