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
                            WagerHistoryCard(wager: wager)
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
    let bet_id: Int
    let title: String
    let outcome_label: String
    let stake: Double
    let locked_coefficient: Double
    let potential_return: Double
    let status: String
    let bet_status: String
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
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack {
                Text(wager.title)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(wager.status.uppercased())
                    .font(.caption2)
                    .bold()
                    .padding(4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            Text("Picked: \(wager.outcome_label) @ \(String(format: "%.2f", wager.locked_coefficient))")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            
            Divider().background(AppTheme.textSecondary.opacity(0.2))
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Stake")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("\(String(format: "%.2f", wager.stake))€")
                        .foregroundColor(AppTheme.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(wager.status == "won" ? "Payout" : "Potential Payout")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("\(String(format: "%.2f", wager.potential_return))€")
                        .bold()
                        .foregroundColor(wager.status == "won" ? AppTheme.oddsUp : AppTheme.textPrimary)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.m)
    }
}
