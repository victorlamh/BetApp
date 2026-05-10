import SwiftUI

struct MyBetsView: View {
    @State private var wagers: [WagerHistoryItem] = []
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView().tint(AppTheme.primary)
            } else if wagers.isEmpty {
                VStack(spacing: AppTheme.Spacing.m) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.3))
                    Text("No bets placed yet")
                        .foregroundColor(AppTheme.textSecondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.m) {
                        ForEach(wagers) { wager in
                            NavigationLink(destination: BetDetailView(betId: wager.betId)) {
                                WagerHistoryCard(wager: wager)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("My Bets")
        .task { await fetchWagers() }
    }
    
    private func fetchWagers() async {
        isLoading = true
        do {
            let fetched: [WagerHistoryItem] = try await APIClient.shared.request("wagers/my_bets.php")
            DispatchQueue.main.async {
                self.wagers = fetched
                self.isLoading = false
            }
        } catch {
            print("Wager fetch error: \(error)")
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
}

struct WagerHistoryItem: Identifiable, Decodable {
    let id: Int
    let betId: Int
    let title: String
    let outcomeLabel: String
    let stake: Double
    let lockedCoefficient: Double
    let potentialReturn: Double
    let status: String
    let betStatus: String
    let winningOutcomeLabel: String?
}

struct WagerHistoryCard: View {
    let wager: WagerHistoryItem
    
    var statusColor: Color {
        switch wager.status {
        case "won": return AppTheme.oddsUp
        case "lost": return AppTheme.oddsDown
        case "void": return .orange
        default: return AppTheme.primary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            HStack {
                Text(wager.title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Text(wager.status.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .foregroundColor(.black)
                    .cornerRadius(6)
            }
            
            HStack {
                Text(wager.outcomeLabel)
                    .font(.headline).bold()
                    .foregroundColor(.white)
                
                if let winner = wager.winningOutcomeLabel, wager.status == "lost" {
                    Text("•")
                        .foregroundColor(.white)
                    Text("Winner: \(winner)")
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.oddsUp)
                }
                
                Spacer()
                Text("@ \(String(format: "%.2f", wager.lockedCoefficient))")
                    .font(.system(.title3, design: .monospaced))
                    .bold()
                    .foregroundColor(AppTheme.primary)
            }
            .padding(.vertical, 4)
            
            Divider().background(AppTheme.primary.opacity(0.3)) // No more grey divider
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STAKE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white) // No more grey text
                    Text("\(String(format: "%.2f", wager.stake))€")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(wager.status == "won" ? "PAYOUT" : "POTENTIAL")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white) // No more grey text
                    Text("\(String(format: "%.2f", wager.potentialReturn))€")
                        .font(.title2.bold())
                        .foregroundColor(wager.status == "won" ? AppTheme.oddsUp : .white)
                }
            }
        }
        .padding()
        .background(Color.black) // Pure black card, NO grey
        .cornerRadius(AppTheme.Radius.m)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                .stroke(wager.status == "active" ? AppTheme.primary : AppTheme.primary.opacity(0.5), lineWidth: 2) // Bright gold border
        )
    }
}
