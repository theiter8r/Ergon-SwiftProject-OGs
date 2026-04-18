import SwiftUI
import Combine

struct BreathingView: View {
    @EnvironmentObject var vm: EloViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var scale: CGFloat = 0.6
    @State private var blur: CGFloat = 20
    @State private var instruction = "Prepare"
    @State private var timerValue = 4
    @State private var isAnimating = false
    @State private var completedCycles = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            LiquidBackgroundView(level: vm.riskLevel)
            
            VStack(spacing: 60) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(completedCycles)/4 Cycles")
                        .font(.caption.bold())
                }
                .padding()
                
                Spacer()
                
                // Morphing Liquid Orb
                ZStack {
                    Circle()
                        .fill(vm.riskLevel.color.opacity(0.3))
                        .frame(width: 250, height: 250)
                        .blur(radius: blur)
                        .scaleEffect(scale)
                    
                    Circle()
                        .stroke(vm.riskLevel.color.opacity(0.5), lineWidth: 2)
                        .frame(width: 260, height: 260)
                        .scaleEffect(scale)
                    
                    Text("\(timerValue)")
                        .font(.system(size: 80, weight: .black, design: .rounded))
                        .contentTransition(.numericText())
                }
                
                VStack(spacing: 12) {
                    Text(instruction.uppercased())
                        .font(.title.bold())
                        .tracking(4)
                    
                    Text("Follow the liquid rhythm")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .onReceive(timer) { _ in
            updateBreathing()
        }
        .onAppear {
            startInhale()
        }
    }
    
    func updateBreathing() {
        if timerValue > 1 {
            timerValue -= 1
        } else {
            switch instruction {
            case "Inhale":
                startHold()
            case "Hold":
                startExhale()
            case "Exhale":
                completedCycles += 1
                if completedCycles >= 4 {
                    finishSession()
                } else {
                    startInhale()
                }
            default:
                startInhale()
            }
        }
    }
    
    func startInhale() {
        instruction = "Inhale"
        timerValue = 4
        withAnimation(.easeInOut(duration: 4)) {
            scale = 1.2
            blur = 40
        }
    }
    
    func startHold() {
        instruction = "Hold"
        timerValue = 4
    }
    
    func startExhale() {
        instruction = "Exhale"
        timerValue = 4
        withAnimation(.easeInOut(duration: 4)) {
            scale = 0.6
            blur = 20
        }
    }
    
    func finishSession() {
        vm.riskScore = max(0, vm.riskScore - 1.0)
        vm.currentElo += 10
        vm.history.insert(EloHistoryEvent(date: Date(), change: 10, reason: "Deep Breathing Session"), at: 0)
        dismiss()
    }
}
