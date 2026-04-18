import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: EloViewModel
    @State private var showLogSheet = false
    @State private var showBreathing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LiquidBackgroundView(level: vm.riskLevel)
                
                ScrollView {
                    // Header
                    HeaderView(vm: vm)
                        .padding(.top, 10)
                        .floatingOnLiquid()

                    if !vm.backendSyncMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(vm.backendSyncMessage)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                    }
                    
                    // Season Progress
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("SEASON 1")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("4 Days Remaining")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                        }
                        
                        ProgressView(value: 0.75)
                            .tint(.blue)
                        
                        Text("Finish in the top 3 of your league for a bonus.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .refractiveGlass()
                    .floatingOnLiquid()
                    
                    // Risk Dial
                    if vm.isAnalyzing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(2)
                                .tint(Color(hex: "#00FFA3"))
                            Text("Analyzing Vitals...")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(height: 300)
                        .refractiveGlass()
                    } else {
                        VStack(spacing: 20) {
                            RiskDialView(score: vm.riskScore, level: vm.riskLevel)
                                .padding(.vertical, 20)
                            
                            if vm.riskLevel == .high {
                                Button {
                                    showBreathing = true
                                } label: {
                                    Label("Start Liquid Breath", systemImage: "wind")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.red.opacity(0.6))
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .padding(.top, -10)
                            }
                        }
                        .refractiveGlass()
                        .floatingOnLiquid()
                    }
                    
                    // League Standings Preview
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(vm.currentLeague.rawValue.uppercased())
                                .font(.caption.bold())
                                .foregroundStyle(vm.currentLeague.color)
                            
                            Spacer()
                            
                            NavigationLink(destination: LeaderboardView()) {
                                Text("View All")
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        ForEach(vm.leaderboard.prefix(3)) { peer in
                            HStack {
                                Image(systemName: peer.avatar)
                                    .foregroundStyle(peer.isUser ? .blue : .secondary)
                                Text(peer.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(peer.isUser ? .blue : .primary)
                                Spacer()
                                Text("\(peer.elo)")
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                    }
                    .padding(20)
                    .refractiveGlass()
                    
                    // Micro-Task Card
                    if let task = vm.activeTasks.first {
                        MicroTaskCard(task: task) {
                            vm.completeTask(task)
                        }
                        .refractiveGlass()
                        .floatingOnLiquid()
                    } else {
                        EmptyTaskView()
                            .refractiveGlass()
                    }
                    
                    // Action CTA
                    Button {
                        showLogSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Log Evening Check-in")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#00FFA3").opacity(0.15))
                        .foregroundStyle(Color(hex: "#00FFA3"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "#00FFA3").opacity(0.3), lineWidth: 1)
                        )
                    }
                    .sensoryFeedback(.selection, trigger: showLogSheet)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
            }
            .confettiTrigger(vm.currentElo)
            .blur(radius: vm.isAnalyzing ? 10 : 0)
        }
        .sheet(isPresented: $showLogSheet) {
            LogSheetView()
        }
        .fullScreenCover(isPresented: $showBreathing) {
            BreathingView()
        }
    }
}

// MARK: - Subviews

struct HeaderView: View {
    @ObservedObject var vm: EloViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("WELCOME BACK,")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                
                Text(vm.userName.uppercased())
                    .font(.system(size: 24, weight: .black, design: .rounded))
                
                HStack(spacing: 4) {
                    Image(systemName: vm.currentTier.icon)
                    Text(vm.currentTier.rawValue.uppercased())
                }
                .font(.caption.bold())
                .foregroundStyle(.yellow)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(vm.currentElo)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                
                Text("ELO RATING")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Text("🔥 \(vm.streak)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    
                    if vm.streakMultiplier > 1.0 {
                        Text("\(vm.streakMultiplier, specifier: "%.1f")x")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(20)
    }
}

struct RiskDialView: View {
    let score: Double
    let level: RiskLevel
    
    @State private var animatedScore: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background Circle
                Circle()
                    .stroke(level.color.opacity(0.1), lineWidth: 24)
                
                // Progress Circle
                Circle()
                    .trim(from: 0, to: animatedScore / 10.0)
                    .stroke(
                        level.color,
                        style: StrokeStyle(lineWidth: 24, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: -5) {
                    Text("\(score, specifier: "%.1f")")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                    
                    Text("RISK SCORE")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 240, height: 240)
            .shadow(color: level.color.opacity(0.3), radius: 20)
            
            Text(level.rawValue.uppercased() + " RISK")
                .font(.headline.bold())
                .foregroundStyle(level.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(level.color.opacity(0.1))
                .clipShape(Capsule())
        }
        .onAppear {
            withAnimation(.spring(duration: 1.2)) {
                animatedScore = score
            }
        }
        .onChange(of: score) {
            withAnimation(.spring(duration: 0.8)) {
                animatedScore = score
            }
        }
    }
}

struct MicroTaskCard: View {
    let task: MicroTask
    let onComplete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT MISSION")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    
                    Text(task.title)
                        .font(.title3.bold())
                }
                Spacer()
                
                Text("+\(task.rewardElo) ELO")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#00FFA3").opacity(0.2))
                    .foregroundStyle(Color(hex: "#00FFA3"))
                    .clipShape(Capsule())
            }
            
            Text(task.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: onComplete) {
                Text("Complete Task")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .sensoryFeedback(.success, trigger: task.id)
        }
        .padding(24)
    }
}

struct EmptyTaskView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(Color(hex: "#00FFA3"))
            
            Text("All caught up!")
                .font(.headline)
            
            Text("Check back later for more missions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

#Preview {
    HomeView()
        .environmentObject(EloViewModel())
}
