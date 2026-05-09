import SwiftUI

struct AdminView: View {
    @State private var pendingBets: [Bet] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView().tint(AppTheme.primary)
                } else if pendingBets.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Inbox Zero!")
                            .font(.headline)
                        Text("All bets have been moderated.")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(pendingBets) { bet in
                            AdminBetCard(bet: bet, onAction: fetchPendingBets)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Admin Panel")
            .onAppear(perform: fetchPendingBets)
        }
    }
    
    func fetchPendingBets() {
        isLoading = true
        Task {
            do {
                let bets: [Bet] = try await APIClient.shared.request("bets/list.php?status=pending_review")
                DispatchQueue.main.async {
                    self.pendingBets = bets
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async { self.isLoading = false }
            }
        }
    }
}

struct AdminBetCard: View {
    let bet: Bet
    let onAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(bet.creatorName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.primary.opacity(0.2))
                    .foregroundColor(AppTheme.primary)
                    .cornerRadius(4)
                Spacer()
                Text(bet.statusLabel)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Text(bet.title)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            HStack(spacing: 12) {
                Button(action: { moderate(approve: true) }) {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                        .font(.subheadline).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
                
                Button(action: { moderate(approve: false) }) {
                    Label("Reject", systemImage: "xmark.circle.fill")
                        .font(.subheadline).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.m)
    }
    
    func moderate(approve: Bool) {
        // We'll create an admin moderation endpoint for this
        Task {
            do {
                struct SimpleResponse: Decodable { let status: String }
                let _: SimpleResponse = try await APIClient.shared.request(
                    "moderator/review.php",
                    method: "POST",
                    body: [
                        "bet_id": bet.id,
                        "action": approve ? "approve" : "reject",
                        "notes": "Moderated via iOS App"
                    ]
                )
                DispatchQueue.main.async { onAction() }
            } catch {
                print("Moderation failed")
            }
        }
    }
}
