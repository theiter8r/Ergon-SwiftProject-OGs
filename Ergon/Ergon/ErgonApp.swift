import SwiftUI
import Combine

@main
struct ErgonApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var eloViewModel = EloViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(eloViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
