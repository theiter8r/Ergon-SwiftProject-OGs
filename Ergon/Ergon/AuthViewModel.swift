import Foundation
import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    
    func signInWithGoogle() {
        // Mocking Google Sign-In
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring()) {
                self.isAuthenticated = true
            }
        }
    }
    
    func signOut() {
        withAnimation(.spring()) {
            self.isAuthenticated = false
        }
    }
}
