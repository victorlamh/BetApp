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
                    VStack {
                        Text("No pending bets").foregroundColor(AppTheme.textSecondary)
                        Button("Refresh") { fetchPendingBets() }
                            .padding().background(AppTheme.primary).foregroundColor(.white).cornerRadius(8)
                    }
                } else {
                    List(pendingBets) { bet in
                        AdminBetCard(bet: bet, onAction: fetchPendingBets)
                    }
                    .listStyle(.plain)
                    .refreshable { fetchPendingBets() }
                }
            }
            .navigationTitle("Admin Panel")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { fetchPendingBets() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear { fetchPendingBets() }
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
                print("Fetch Failed: \(error)")
                DispatchQueue.main.async { self.isLoading = false }
            }
        }
    }
}

struct AdminBetCard: View {
    let bet: Bet
    let onAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(bet.title).font(.headline).foregroundColor(AppTheme.textPrimary)
            Text("By: \(bet.creatorName)").font(.caption).foregroundColor(AppTheme.textSecondary)
            
            HStack {
                Button("Approve") { moderate(approve: true) }
                    .padding(8).background(Color.green).foregroundColor(.white).cornerRadius(5)
                Button("Reject") { moderate(approve: false) }
                    .padding(8).background(Color.red).foregroundColor(.white).cornerRadius(5)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(10)
    }
    
    func moderate(approve: Bool) {
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
