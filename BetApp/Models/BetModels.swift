import Foundation

struct Bet: Codable, Identifiable {
    let id: Int
    let creatorUserId: Int
    let creatorName: String
    let title: String
    let description: String?
    let category: String?
    let visibility: String
    let status: String
    let isBoosted: Int
    let proofRequired: Int
    let closeAt: String
    let outcomes: [BetOutcome]
    let myWager: Wager?
    
    var statusLabel: String {
        status.replacingOccurrences(of: "_", with: " ").uppercased()
    }
}

struct BetOutcome: Codable, Identifiable {
    let id: Int
    let label: String
    let coefficient: Double
}

struct Wager: Codable, Identifiable {
    let id: Int
    let betId: Int
    let outcomeId: Int
    let stake: Double
    let lockedCoefficient: Double
    let potentialReturn: Double
    let status: String
}
