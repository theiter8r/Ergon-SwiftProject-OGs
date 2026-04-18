import SwiftUI

struct ParticleEffect: ViewModifier {
    @State private var particles: [Particle] = []
    var trigger: Int
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            ForEach(particles) { particle in
                Text("✨")
                    .font(.system(size: particle.size))
                    .position(particle.position)
                    .opacity(particle.opacity)
            }
        }
        .onChange(of: trigger) {
            spawnParticles()
        }
    }
    
    func spawnParticles() {
        for _ in 0...15 {
            let p = Particle()
            particles.append(p)
            
            withAnimation(.easeOut(duration: 1.5)) {
                if let index = particles.firstIndex(where: { $0.id == p.id }) {
                    particles[index].position.y -= 200
                    particles[index].position.x += CGFloat.random(in: -100...100)
                    particles[index].opacity = 0
                }
            }
        }
        
        // Cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            particles.removeAll()
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position = CGPoint(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
    var opacity: Double = 1.0
    var size: CGFloat = CGFloat.random(in: 10...30)
}

extension View {
    func confettiTrigger(_ trigger: Int) -> some View {
        self.modifier(ParticleEffect(trigger: trigger))
    }
}
