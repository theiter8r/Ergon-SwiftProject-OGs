import SwiftUI

struct LiquidBackgroundView: View {
    let level: RiskLevel
    @State private var t: Float = 0.0
    
    // Colors based on risk level
    var colors: [Color] {
        switch level {
        case .low:
            return [Color(hex: "#00FFA3"), .blue, .black, .black]
        case .moderate:
            return [Color(hex: "#FFD600"), .orange, .black, .black]
        case .high:
            return [Color(hex: "#FF4B4B"), .purple, .black, .black]
        }
    }
    
    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5], [0.5, 0.5], [1, 0.5],
                        [0, 1], [0.5, 1], [1, 1]
                    ].map { point in
                        let x = point[0]
                        let y = point[1]
                        let sinT = sin(t + Float(x * 2.0))
                        let cosT = cos(t + Float(y * 2.0))
                        return [
                            Float(x) + sinT * 0.1,
                            Float(y) + cosT * 0.1
                        ]
                    },
                    colors: [
                        colors[2], colors[2], colors[2],
                        colors[3], colors[0].opacity(0.3), colors[3],
                        colors[1].opacity(0.2), colors[2], colors[2]
                    ]
                )
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.linear(duration: 10).repeatForever(autoreverses: true)) {
                        t = 2.0 * .pi
                    }
                }
                .blur(radius: 60)
            } else {
                // Fallback for older iOS versions
                LinearGradient(
                    colors: [colors[0].opacity(0.6), colors[1].opacity(0.6), colors[2]],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .blur(radius: 30)
            }
        }
    }
}

// Extension to allow array mapping for points
extension Array where Element == [Float] {
    func mapPoints() -> [SIMD2<Float>] {
        self.map { SIMD2<Float>($0[0], $0[1]) }
    }
}
