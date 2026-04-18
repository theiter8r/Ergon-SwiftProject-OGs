import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func playSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func playWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    func playImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    func playLevelUp() {
        // Complex pattern: double impact + success
        playImpact()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playImpact()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.playSuccess()
        }
    }
}
