import Foundation
import SwiftUI

enum RiskLevel: String, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    
    var color: Color {
        switch self {
        case .low: return Color(hex: "#00FFA3")
        case .moderate: return Color(hex: "#FFD600")
        case .high: return Color(hex: "#FF4B4B")
        }
    }
}

enum Tier: String, CaseIterable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case platinum = "Platinum"
    case diamond = "Diamond"
    
    var icon: String {
        switch self {
        case .bronze: return "seal"
        case .silver: return "seal.fill"
        case .gold: return "medal"
        case .platinum: return "medal.fill"
        case .diamond: return "crown.fill"
        }
    }
}

struct MicroTask: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let rewardElo: Int
    let riskContext: RiskLevel
}

struct EloHistoryEvent: Identifiable, Codable {
    let id: UUID
    let date: Date
    let change: Int
    let reason: String
    
    // Vitals for correlation
    var sleepHours: Double?
    var hrv: Double?
    
    init(id: UUID = UUID(), date: Date, change: Int, reason: String, sleepHours: Double? = nil, hrv: Double? = nil) {
        self.id = id
        self.date = date
        self.change = change
        self.reason = reason
        self.sleepHours = sleepHours
        self.hrv = hrv
    }
}

struct LeaderboardPeer: Identifiable, Codable {
    let id: UUID
    let name: String
    var elo: Int
    let avatar: String
    var isUser: Bool = false
}

enum League: String, CaseIterable, Codable {
    case bronze = "Bronze League"
    case silver = "Silver League"
    case gold = "Gold League"
    case platinum = "Platinum League"
    case diamond = "Diamond League"
    
    var color: Color {
        switch self {
        case .bronze: return .orange
        case .silver: return .gray
        case .gold: return .yellow
        case .platinum: return .cyan
        case .diamond: return .blue
        }
    }
}

struct Milestone: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let icon: String
    let requiredElo: Int
    var isEarned: Bool = false
    var isClaimed: Bool = false
    
    init(id: UUID = UUID(), title: String, description: String, icon: String, requiredElo: Int, isEarned: Bool = false, isClaimed: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.requiredElo = requiredElo
        self.isEarned = isEarned
        self.isClaimed = isClaimed
    }
}


// Helper for Hex Colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
