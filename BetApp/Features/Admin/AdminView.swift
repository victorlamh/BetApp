import SwiftUI

struct AdminView: View {
    @State private var pendingBets: [Bet] = []
    @State private var isLoading = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Always-visible debug info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Token: \(AuthStore.shared.token != nil ? "✅ Present" : "❌ Missing")")
                        Text("Bets loaded: \(pendingBets.count)")
                        if !errorMessage.isEmpty {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView("Loading bets...").tint(AppTheme.primary)
                    } else if pendingBets.isEmpty {
                        VStack(spacing: 12) {
                            Text("No pending bets found")
                                .foregroundColor(AppTheme.textSecondary)
                            Button("Retry") { fetchPendingBets() }
                                .padding()
                                .background(AppTheme.primary)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    } else {
                        List(pendingBets) { bet in
                            AdminBetCard(bet: bet, onAction: fetchPendingBets)
                        }
                        .listStyle(.plain)
                        .refreshable { fetchPendingBets() }
                    }
                }
            }
            .navigationTitle("Admin Panel")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: fetchPendingBets) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear { fetchPendingBets() }
        }
    }
    
    func fetchPendingBets() {
        errorMessage = "Fetching..."
        isLoading = true
        let url = "bets/list.php?status=pending_review"
        Task {
            do {
                let bets: [Bet] = try await APIClient.shared.request(url)
                DispatchQueue.main.async {
                    self.pendingBets = bets
                    self.isLoading = false
                    self.errorMessage = "OK - got \(bets.count) bets"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "FAIL: \(error)"
                }
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
                    body: ["bet_id": bet.id, "action": approve ? "approve" : "reject", "notes": "Moderated via iOS"]
                )
                DispatchQueue.main.async { onAction() }
            } catch {
                print("Moderation failed: \(error)")
            }
        }
    }
}
