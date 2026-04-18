import SwiftUI

struct RefractiveGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.1),
                                .white.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func refractiveGlass(cornerRadius: CGFloat = 24) -> some View {
        self.modifier(RefractiveGlassModifier(cornerRadius: cornerRadius))
    }
}

// Float effect for 3D parallax
struct FloatEffect: ViewModifier {
    @State private var offset: CGSize = .zero
    
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    offset = CGSize(width: 5, height: 10)
                }
            }
    }
}

extension View {
    func floatingOnLiquid() -> some View {
        self.modifier(FloatEffect())
    }
}
