import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var vm: EloViewModel
    
    var body: some View {
        ZStack {
            LiquidBackgroundView(level: vm.riskLevel)
            
            ScrollView {
                VStack(spacing: 12) {
                    Text(vm.currentLeague.rawValue.uppercased())
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(vm.currentLeague.color)
                        .padding(.top, 20)
                    
                    Text("Season Ends in 4 Days")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                    
                    ForEach(Array(vm.leaderboard.enumerated()), id: \.element.id) { index, peer in
                        HStack(spacing: 16) {
                            Text("\(index + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            
                            Image(systemName: peer.avatar)
                                .font(.title2)
                                .foregroundStyle(peer.isUser ? .blue : .primary)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text(peer.name)
                                    .font(.headline)
                                    .foregroundStyle(peer.isUser ? .blue : .primary)
                                
                                if peer.isUser {
                                    Text("YOU")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.blue)
                                }
                            }
                            
                            Spacer()
                            
                            Text("\(peer.elo)")
                                .font(.title3.bold().monospacedDigit())
                        }
                        .padding()
                        .background(peer.isUser ? Color.blue.opacity(0.1) : Color.clear)
                        .refractiveGlass(cornerRadius: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(peer.isUser ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                        )
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
    }
}
