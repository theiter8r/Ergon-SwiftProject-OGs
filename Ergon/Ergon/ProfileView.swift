import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var vm: EloViewModel
    @AppStorage("pushNotifications") private var pushNotifications = true
    @State private var showResetConfirmation = false
#if DEBUG
    @State private var backendMode: BackendEndpointMode = BackendSyncService.endpointMode()
    @State private var customBackendURL: String = BackendSyncService.customBaseURL()
    @State private var backendIDToken: String = BackendSyncService.backendIDToken()
    @State private var firebaseAPIKey: String = FirebaseAuthTokenProvider.apiKey()
#endif
    
    var body: some View {
        NavigationView {
            ZStack {
                LiquidBackgroundView(level: vm.riskLevel)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.blue.gradient)
                            }
                            
                            VStack(spacing: 4) {
                                Text(vm.userName)
                                    .font(.title2.bold())
                                Text(vm.currentTier.rawValue + " Tier")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Milestones / Trophy Room
                        VStack(alignment: .leading, spacing: 16) {
                            Text("TROPHY ROOM")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(vm.milestones) { milestone in
                                    MilestoneCard(milestone: milestone) {
                                        vm.claimMilestone(milestone)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Settings
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SETTINGS")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 1) {
                                Toggle(isOn: $pushNotifications) {
                                    Label("Push Notifications", systemImage: "bell.fill")
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                
                                Button {
                                    Task {
                                        NotificationManager.shared.requestAuthorization()
                                        do {
                                            try await HealthKitManager.shared.generateRealisticDummyData()
                                            vm.submitLog(mental: 1.0, sleep: 4.0, disconnect: 2.0)
                                        } catch {
                                            print("Error generating mock data: \(error)")
                                        }
                                    }
                                } label: {
                                    Label("Test AI Alert & Mock HealthKit", systemImage: "bolt.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                
                                Button(role: .destructive) {
                                    showResetConfirmation = true
                                } label: {
                                    Label("Reset All Progress", systemImage: "trash.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .padding(.horizontal)

#if DEBUG
                        BackendDebugSettingsCard(
                            selectedMode: $backendMode,
                            customBaseURL: $customBackendURL,
                            firebaseAPIKey: $firebaseAPIKey,
                            idToken: $backendIDToken,
                            tokenStatusMessage: vm.backendTokenStatusMessage,
                            tokenStatusIsValid: vm.backendTokenStatusIsValid,
                            isVerifyingToken: vm.isVerifyingBackendToken,
                            onVerifyToken: vm.verifyBackendToken,
                            onApply: applyBackendDebugSettings
                        )
                        .padding(.horizontal)
#endif
                        Spacer(minLength: 0)
                            .frame(height: 30)
                    }
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog("Reset Progress?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                Button("Reset Everything", role: .destructive) {
                    vm.resetProgress()
                }
            } message: {
                Text("This will permanently delete your ELO, history, and achievements.")
            }
        }
    }

#if DEBUG
    private func applyBackendDebugSettings() {
        BackendSyncService.setEndpointMode(backendMode)
        BackendSyncService.setCustomBaseURL(customBackendURL)
        BackendSyncService.setBackendIDToken(backendIDToken)
        FirebaseAuthTokenProvider.setAPIKey(firebaseAPIKey)
        FirebaseAuthTokenProvider.clearSession()
        BackendSyncService.clearLegacyBaseURLOverride()
        vm.backendSyncMessage = "Backend debug settings applied"
        vm.syncProfileToBackend()
        vm.verifyBackendToken()
    }
#endif
}

struct MilestoneCard: View {
    let milestone: Milestone
    let onClaim: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(milestone.isEarned ? Color(hex: "#00FFA3").opacity(0.1) : Color.white.opacity(0.05))
                    .frame(width: 60, height: 60)
                
                Image(systemName: milestone.icon)
                    .font(.title2)
                    .foregroundStyle(milestone.isEarned ? Color(hex: "#00FFA3") : .secondary)
                
                if !milestone.isEarned {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .offset(x: 20, y: 20)
                }
            }
            
            VStack(spacing: 4) {
                Text(milestone.title)
                    .font(.headline)
                Text(milestone.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if milestone.isEarned && !milestone.isClaimed {
                Button("Claim +50") {
                    onClaim()
                }
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#00FFA3"))
                .foregroundStyle(.black)
                .clipShape(Capsule())
            } else if milestone.isClaimed {
                Text("Claimed")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            } else {
                Text("\(milestone.requiredElo) ELO")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .opacity(milestone.isEarned ? 1.0 : 0.6)
    }
}

#if DEBUG
struct BackendDebugSettingsCard: View {
    @Binding var selectedMode: BackendEndpointMode
    @Binding var customBaseURL: String
    @Binding var firebaseAPIKey: String
    @Binding var idToken: String
    let tokenStatusMessage: String
    let tokenStatusIsValid: Bool
    let isVerifyingToken: Bool
    let onVerifyToken: () -> Void
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BACKEND DEBUG")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Picker("Backend", selection: $selectedMode) {
                ForEach(BackendEndpointMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if selectedMode == .custom {
                TextField("https://host/project/region", text: $customBaseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption.monospaced())
                    .padding(10)
                    .background(.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            TextField("Firebase Web API Key", text: $firebaseAPIKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.caption.monospaced())
                .padding(10)
                .background(.black.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            SecureField("Manual Firebase ID token override (optional)", text: $idToken)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.caption.monospaced())
                .padding(10)
                .background(.black.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 8) {
                Circle()
                    .fill(tokenStatusIsValid ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(tokenStatusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onVerifyToken()
                } label: {
                    if isVerifyingToken {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Check")
                            .font(.caption.bold())
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isVerifyingToken)
            }

            Text("Active URL: \(BackendSyncService.resolvedBaseURLString())")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(action: onApply) {
                Text("Apply & Sync Profile")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
#endif

