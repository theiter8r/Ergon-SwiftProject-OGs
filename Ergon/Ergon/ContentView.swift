import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: EloViewModel
    
    var body: some View {
        Group {
            if vm.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Dashboard", systemImage: "bolt.fill")
                }
            
            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.xyaxis.line")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}
