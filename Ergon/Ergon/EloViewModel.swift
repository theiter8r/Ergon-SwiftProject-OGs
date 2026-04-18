import Foundation
import SwiftUI
import Combine

class EloViewModel: ObservableObject {
    @Published var currentElo: Int = 1200 { didSet { saveProgress() } }
    @Published var riskScore: Double = 2.4 { didSet { saveProgress() } }
    @Published var streak: Int = 5 { didSet { saveProgress() } }
    @Published var userName: String = "User" { didSet { saveProgress() } }
    @Published var lastCompletedTaskDateKey: String? = nil { didSet { saveProgress() } }
    @Published var hasCompletedOnboarding: Bool = false { didSet { saveProgress() } }
    @Published var isAnalyzing: Bool = false
    @Published var backendSyncMessage: String = ""
    @Published var backendTokenStatusMessage: String = "Not verified"
    @Published var backendTokenStatusIsValid: Bool = false
    @Published var isVerifyingBackendToken: Bool = false
    
    // Core ML and HealthKit integrations
    private let analyzer = BurnoutAnalyzer()
    private let healthKit = HealthKitManager.shared
    private let backendSync = BackendSyncService()
    
    @Published var history: [EloHistoryEvent] = [] { didSet { saveProgress() } }
    @Published var activeTasks: [MicroTask] = []
    
    @Published var milestones: [Milestone] = [
        Milestone(title: "The Novice", description: "Reached 1300 ELO.", icon: "leaf.fill", requiredElo: 1300),
        Milestone(title: "Zen Master", description: "Reached 1600 ELO.", icon: "sparkles", requiredElo: 1600),
        Milestone(title: "Burnout Proof", description: "Reached 2000 ELO.", icon: "shield.fill", requiredElo: 2000)
    ] { didSet { saveProgress() } }
    
    // Social / Leaderboard
    @Published var leaderboard: [LeaderboardPeer] = []
    
    private let storageKey = "ergon_user_data"
    private let allTasks: [MicroTask] = [
        MicroTask(title: "10-min Walk", description: "Step away from the screen to lower cortisol.", rewardElo: 15, riskContext: .high),
        MicroTask(title: "Silence Notifications", description: "Turn off non-critical pings for 1 hour.", rewardElo: 20, riskContext: .high),
        MicroTask(title: "Guided Breathing", description: "3 minutes of box breathing.", rewardElo: 10, riskContext: .moderate),
        MicroTask(title: "Power Nap", description: "A quick 15-min reset.", rewardElo: 15, riskContext: .moderate),
        MicroTask(title: "Hydration Hit", description: "Drink 500ml of water.", rewardElo: 5, riskContext: .low),
        MicroTask(title: "Posture Check", description: "30 seconds of shoulder rolls.", rewardElo: 5, riskContext: .low)
    ]
    
    init() {
        loadProgress()
        if history.isEmpty {
            history = [
                EloHistoryEvent(date: Date().addingTimeInterval(-86400 * 3), change: +15, reason: "Evening Check-in"),
                EloHistoryEvent(date: Date().addingTimeInterval(-86400 * 2), change: -10, reason: "High Stress Detected"),
                EloHistoryEvent(date: Date().addingTimeInterval(-86400 * 1), change: +20, reason: "Deep Sleep Goal Met")
            ]
        }
        generateLeaderboard()
        refreshTasks()
        syncProfileToBackend()
    }
    
    // MARK: - Social Logic
    
    func generateLeaderboard() {
        let names = ["Alex", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Jamie"]
        let avatars = ["person.circle.fill", "person.crop.circle.badge.checkmark", "person.crop.circle.fill", "person.circle"]
        
        var peers = names.map { name in
            LeaderboardPeer(
                id: UUID(),
                name: name,
                elo: currentElo + Int.random(in: -150...150),
                avatar: avatars.randomElement() ?? "person.circle"
            )
        }
        
        let user = LeaderboardPeer(id: UUID(), name: userName, elo: currentElo, avatar: "person.crop.circle.fill.badge.plus", isUser: true)
        peers.append(user)
        
        leaderboard = peers.sorted(by: { $0.elo > $1.elo })
    }
    
    func updateLeaderboard() {
        if let index = leaderboard.firstIndex(where: { $0.isUser }) {
            let existing = leaderboard[index]
            let updated = LeaderboardPeer(
                id: existing.id,
                name: userName,
                elo: currentElo,
                avatar: existing.avatar,
                isUser: existing.isUser
            )
            leaderboard[index] = updated
        }
        
        // Randomly simulate peer activity
        for i in leaderboard.indices where !leaderboard[i].isUser {
            let delta = Int.random(in: -5...10)
            let peer = leaderboard[i]
            leaderboard[i] = LeaderboardPeer(
                id: peer.id,
                name: peer.name,
                elo: peer.elo + delta,
                avatar: peer.avatar,
                isUser: peer.isUser
            )
        }
        
        leaderboard.sort(by: { $0.elo > $1.elo })
    }
    
    var currentLeague: League {
        switch currentElo {
        case ..<1100: return .bronze
        case 1100..<1300: return .silver
        case 1300..<1600: return .gold
        case 1600..<2000: return .platinum
        default: return .diamond
        }
    }
    
    // MARK: - Persistence
    
    struct PersistableData: Codable {
        let elo: Int
        let risk: Double
        let streak: Int
        let lastCompletedTaskDateKey: String?
        let history: [EloHistoryEvent]
        let milestones: [Milestone]
        let userName: String
        let hasCompletedOnboarding: Bool
    }
    
    private func saveProgress() {
        let data = PersistableData(
            elo: currentElo,
            risk: riskScore,
            streak: streak,
            lastCompletedTaskDateKey: lastCompletedTaskDateKey,
            history: history,
            milestones: milestones,
            userName: userName,
            hasCompletedOnboarding: hasCompletedOnboarding
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        updateLeaderboard()
    }
    
    private func loadProgress() {
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(PersistableData.self, from: savedData) {
            currentElo = decoded.elo
            riskScore = decoded.risk
            streak = decoded.streak
            lastCompletedTaskDateKey = decoded.lastCompletedTaskDateKey
            history = decoded.history
            milestones = decoded.milestones
            userName = decoded.userName
            hasCompletedOnboarding = decoded.hasCompletedOnboarding
        }
    }
    
    var currentTier: Tier {
        switch currentElo {
        case ..<1000: return .bronze
        case 1000..<1200: return .silver
        case 1200..<1500: return .gold
        case 1500..<2000: return .platinum
        default: return .diamond
        }
    }
    
    var riskLevel: RiskLevel {
        switch riskScore {
        case 0...3: return .low
        case 3.1...6: return .moderate
        default: return .high
        }
    }
    
    var streakMultiplier: Double {
        if streak >= 30 { return 2.0 }
        if streak >= 7 { return 1.5 }
        if streak >= 3 { return 1.2 }
        return 1.0
    }
    
    func refreshTasks() {
        activeTasks = allTasks.filter { $0.riskContext == riskLevel }.shuffled().prefix(1).map { $0 }
    }
    
    func checkMilestones() {
        for index in milestones.indices {
            if !milestones[index].isEarned && currentElo >= milestones[index].requiredElo {
                withAnimation(.spring()) {
                    milestones[index].isEarned = true
                }
            }
        }
    }
    
    func claimMilestone(_ milestone: Milestone) {
        if let index = milestones.firstIndex(where: { $0.id == milestone.id }), milestones[index].isEarned && !milestones[index].isClaimed {
            HapticManager.shared.playLevelUp()
            withAnimation(.spring()) {
                milestones[index].isClaimed = true
                currentElo += 50
                history.insert(EloHistoryEvent(date: Date(), change: 50, reason: "Milestone: \(milestone.title)"), at: 0)
            }
        }
    }
    
    @MainActor
    func completeTask(_ task: MicroTask) {
        HapticManager.shared.playSuccess()
        withAnimation(.spring()) {
            let baseReward = Double(task.rewardElo)
            let totalReward = Int(baseReward * streakMultiplier)
            
            currentElo += totalReward
            streak += 1
            
            let newEvent = EloHistoryEvent(
                date: Date(),
                change: totalReward,
                reason: "Task: \(task.title) (\(streakMultiplier)x)"
            )
            history.insert(newEvent, at: 0)
            lastCompletedTaskDateKey = BackendSyncService.dateKeyUTC()
            
            activeTasks.removeAll { $0.id == task.id }
            checkMilestones()
            
            if riskScore > 3.0 {
                riskScore -= 0.5
            }
        }
    }
    
    @MainActor
    func applyDailyDecay() {
        if riskScore > 7.0 {
            let penalty = -20
            currentElo += penalty
            history.insert(EloHistoryEvent(date: Date(), change: penalty, reason: "High Risk Neglect"), at: 0)
        }
    }
    
    @MainActor
    func submitLog(mental: Double, sleep: Double, disconnect: Double) {
        isAnalyzing = true
        let dateKey = BackendSyncService.dateKeyUTC()
        let completedMicrotaskToday = lastCompletedTaskDateKey == dateKey
        
        Task {
            let realSleep = (try? await healthKit.fetchLastNightSleep()) ?? 7.0
            let realHRV = (try? await healthKit.fetchTodayHRV()) ?? 60.0
            let calendarDensity = 11.0 - disconnect
            
            await analyzer.predictRisk(sleepHours: realSleep, hrv: realHRV, calendarDensity: calendarDensity, subjectiveScore: mental)
            
            let syncedRiskScore = await MainActor.run { () -> Double in
                withAnimation(.spring()) {
                    updateRiskFromLabel(analyzer.currentRisk)
                    
                    let reward = Int(25 * streakMultiplier)
                    currentElo += reward
                    
                    let newEvent = EloHistoryEvent(
                        date: Date(),
                        change: reward,
                        reason: "Daily Check-in (Health Synced)",
                        sleepHours: realSleep,
                        hrv: realHRV
                    )

                    history.insert(newEvent, at: 0)
                    
                    isAnalyzing = false
                    refreshTasks()
                    checkMilestones()
                    
                    // Trigger AI Notification if high risk
                    if self.riskLevel == .high {
                        NotificationManager.shared.sendAIBurnoutAlert(riskLevel: analyzer.currentRisk)
                    }
                }
                return riskScore
            }

            syncDailyInsightToBackend(
                dateKey: dateKey,
                riskScore: syncedRiskScore,
                completedMicrotask: completedMicrotaskToday,
                mentalEnergy: mental,
                sleepQuality: sleep,
                digitalDisconnect: disconnect
            )
        }
    }
    
    func resetProgress() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        currentElo = 1200
        riskScore = 2.4
        streak = 5
        userName = "User"
        lastCompletedTaskDateKey = nil
        history = []
        milestones = [
            Milestone(title: "The Novice", description: "Reached 1300 ELO.", icon: "leaf.fill", requiredElo: 1300),
            Milestone(title: "Zen Master", description: "Reached 1600 ELO.", icon: "sparkles", requiredElo: 1600),
            Milestone(title: "Burnout Proof", description: "Reached 2000 ELO.", icon: "shield.fill", requiredElo: 2000)
        ]
        hasCompletedOnboarding = false
        syncProfileToBackend()
    }

    func syncProfileToBackend() {
        if !canSyncToBackend() {
            backendSyncMessage = "Set API key or token in Profile debug"
            return
        }

        let payload = BackendUserProfilePayload(
            uid: nil,
            email: nil,
            display_name: userName,
            fcm_token: nil
        )

        Task {
            do {
                try await backendSync.upsertUserProfile(payload: payload)
                await MainActor.run {
                    backendSyncMessage = "Profile synced"
                    backendTokenStatusMessage = "Token valid"
                    backendTokenStatusIsValid = true
                }
            } catch {
                await MainActor.run {
                    backendSyncMessage = "Profile sync pending"
                    backendTokenStatusMessage = error.localizedDescription
                    backendTokenStatusIsValid = false
                }
                print("Profile sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func syncDailyInsightToBackend(
        dateKey: String,
        riskScore: Double,
        completedMicrotask: Bool,
        mentalEnergy: Double,
        sleepQuality: Double,
        digitalDisconnect: Double
    ) {
        if !canSyncToBackend() {
            Task { @MainActor in
                backendSyncMessage = "Set API key or token in Profile debug"
            }
            return
        }

        let payload = BackendDailyInsightPayload(
            uid: nil,
            date_key: dateKey,
            risk_score: riskScore,
            completed_microtask: completedMicrotask,
            mental_energy: mentalEnergy,
            sleep_quality: sleepQuality,
            digital_disconnect: digitalDisconnect
        )

        Task {
            do {
                try await backendSync.submitDailyInsight(payload: payload)
                await MainActor.run {
                    backendSyncMessage = "Daily insight synced"
                    backendTokenStatusMessage = "Token valid"
                    backendTokenStatusIsValid = true
                }
            } catch {
                await MainActor.run {
                    backendSyncMessage = "Daily insight sync pending"
                    backendTokenStatusMessage = error.localizedDescription
                    backendTokenStatusIsValid = false
                }
                print("Daily insight sync failed: \(error.localizedDescription)")
            }
        }
    }

    func verifyBackendToken() {
        isVerifyingBackendToken = true

        Task {
            do {
                let result = try await backendSync.verifyAuthToken()
                await MainActor.run {
                    let expiryText = formattedExpiry(result.expires_at)
                    backendTokenStatusMessage = "Valid uid: \(result.uid) • exp: \(expiryText)"
                    backendTokenStatusIsValid = true
                    isVerifyingBackendToken = false
                }
            } catch {
                await MainActor.run {
                    backendTokenStatusMessage = error.localizedDescription
                    backendTokenStatusIsValid = false
                    isVerifyingBackendToken = false
                }
            }
        }
    }

    private func canSyncToBackend() -> Bool {
        if !BackendSyncService.backendIDToken().isEmpty {
            return true
        }

        let mode = BackendSyncService.endpointMode()
        if mode == .emulator {
            return true
        }

        return !FirebaseAuthTokenProvider.apiKey().isEmpty
    }

    private func formattedExpiry(_ unix: Int?) -> String {
        guard let unix else {
            return "unknown"
        }

        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        return date.formatted(date: .omitted, time: .shortened)
    }
    
    private func updateRiskFromLabel(_ label: String) {
        switch label {
        case "High": riskScore = 8.5
        case "Medium", "Moderate": riskScore = 5.0
        case "Low": riskScore = 1.5
        default: riskScore = 0.0
        }
    }
}

