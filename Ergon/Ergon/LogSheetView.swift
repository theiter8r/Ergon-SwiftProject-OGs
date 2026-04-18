import SwiftUI

struct LogSheetView: View {
    @EnvironmentObject var vm: EloViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var mentalEnergy: Double = 5.0
    @State private var sleepQuality: Double = 5.0
    @State private var digitalDisconnect: Double = 5.0
    @State private var isSubmitting = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EVENING CHECK-IN")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text("How was your day?")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 40) {
                        TactileSlider(
                            label: "Mental Energy",
                            value: $mentalEnergy,
                            icon: "bolt.fill",
                            color: .yellow
                        )
                        
                        TactileSlider(
                            label: "Sleep Quality",
                            value: $sleepQuality,
                            icon: "bed.double.fill",
                            color: .blue
                        )
                        
                        TactileSlider(
                            label: "Digital Disconnect",
                            value: $digitalDisconnect,
                            icon: "iphone.slash",
                            color: .purple
                        )
                    }
                    .padding(.vertical, 20)
                }
                
                // Submit Button
                Button {
                    handleSubmit()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Submit Reflection")
                                .font(.headline)
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#00FFA3"))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(hex: "#00FFA3").opacity(0.4), radius: 10)
                }
                .disabled(isSubmitting)
                .padding(.bottom, 20)
            }
            .padding(24)
        }
    }
    
    private func handleSubmit() {
        isSubmitting = true
        
        // Haptic Feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Simulate network/processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            vm.submitLog(
                mental: mentalEnergy,
                sleep: sleepQuality,
                disconnect: digitalDisconnect
            )
            
            // Success Haptic
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            
            dismiss()
        }
    }
}

struct TactileSlider: View {
    let label: String
    @Binding var value: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(label)
                    .font(.headline)
                Spacer()
                Text("\(Int(value))/10")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(color)
            }
            
            Slider(value: $value, in: 1...10, step: 1)
                .tint(color)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.1))
                        .frame(height: 8)
                )
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    LogSheetView()
        .environmentObject(EloViewModel())
}
