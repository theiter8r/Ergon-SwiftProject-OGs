import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var vm: EloViewModel
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            LiquidBackgroundView(level: .low)
            
            VStack {
                TabView(selection: $currentPage) {
                    OnboardingPage(
                        title: "Protect Your Focus",
                        description: "Ergon uses ELO to gamify your mental health. Stay above the burnout threshold.",
                        icon: "shield.lefthalf.filled",
                        tag: 0
                    )
                    
                    OnboardingPage(
                        title: "Health Integration",
                        description: "We analyze your Sleep and HRV to predict burnout risk before it happens.",
                        icon: "heart.text.square.fill",
                        tag: 1
                    )
                    
                    PermissionPage(tag: 2)
                    
                    ProfileSetupPage(tag: 3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                
                if currentPage < 3 {
                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(40)
                }
            }
        }
    }
}

struct OnboardingPage: View {
    let title: String
    let description: String
    let icon: String
    let tag: Int
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .refractiveGlass(cornerRadius: 30)
                .floatingOnLiquid()
            
            VStack(spacing: 15) {
                Text(title)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .tag(tag)
    }
}

struct PermissionPage: View {
    let tag: Int
    @State private var healthAuthorized = false
    @State private var notificationsAuthorized = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Permissions")
                .font(.system(size: 32, weight: .black, design: .rounded))
            
            VStack(spacing: 16) {
                PermissionRow(
                    title: "Health Data",
                    description: "Access Sleep & HRV vitals.",
                    icon: "heart.fill",
                    isAuthorized: healthAuthorized
                ) {
                    Task {
                        try? await HealthKitManager.shared.requestAuthorization()
                        healthAuthorized = true
                    }
                }
                
                PermissionRow(
                    title: "Notifications",
                    description: "Reminders for check-ins.",
                    icon: "bell.fill",
                    isAuthorized: notificationsAuthorized
                ) {
                    Task {
                        let isAuthorized = await NotificationManager.shared.updatePushPreference(isEnabled: true)
                        await MainActor.run {
                            notificationsAuthorized = isAuthorized
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .tag(tag)
        .task {
            notificationsAuthorized = await NotificationManager.shared.isAuthorized()
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let icon: String
    let isAuthorized: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isAuthorized ? .green : .blue)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: action) {
                Text(isAuthorized ? "Allowed" : "Allow")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isAuthorized ? .green.opacity(0.2) : .blue.opacity(0.2))
                    .foregroundStyle(isAuthorized ? .green : .blue)
                    .clipShape(Capsule())
            }
            .disabled(isAuthorized)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProfileSetupPage: View {
    let tag: Int
    @EnvironmentObject var vm: EloViewModel
    @State private var nameInput: String = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Text("What's your name?")
                .font(.system(size: 32, weight: .black, design: .rounded))
            
            TextField("Enter name", text: $nameInput)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 40)
            
            Button {
                if !nameInput.isEmpty {
                    vm.userName = nameInput
                }
                vm.syncProfileToBackend()
                withAnimation {
                    vm.hasCompletedOnboarding = true
                }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .tag(tag)
    }
}
