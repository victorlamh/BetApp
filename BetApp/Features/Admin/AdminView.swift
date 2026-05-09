import SwiftUI

struct AdminView: View {
    @ObservedObject var authStore = AuthStore.shared
    @State private var pendingBets: [Bet] = []
    @State private var isLoading = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                if authStore.currentUser?.role != "admin" {
                    VStack {
                        Image(systemName: "lock.shield").font(.largeTitle).foregroundColor(AppTheme.textSecondary)
                        Text("Admin access only").foregroundColor(AppTheme.textSecondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Status bar
                        HStack {
                            Text("Pending: \(pendingBets.count)")
                            Spacer()
                            if !errorMessage.isEmpty {
                                Text(errorMessage).foregroundColor(errorMessage.contains("✅") ? .green : .red)
                            }
                        }
                        .font(.caption.monospaced())
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.yellow)
                        
                        if isLoading {
                            Spacer()
                            ProgressView("Loading...").tint(AppTheme.primary)
                            Spacer()
                        } else if pendingBets.isEmpty {
                            Spacer()
                            Text("No pending bets").foregroundColor(AppTheme.textSecondary)
                            Spacer()
                        } else {
                            List(pendingBets) { bet in
                                AdminBetCard(bet: bet, onAction: fetchPendingBets)
                            }
                            .listStyle(.plain)
                        }
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
            .onAppear {
                if authStore.currentUser?.role == "admin" {
                    fetchPendingBets()
                }
            }
        }
    }
    
    func fetchPendingBets() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                let bets: [Bet] = try await APIClient.shared.request("bets/list.php?status=pending_review")
                DispatchQueue.main.async {
                    self.pendingBets = bets
                    self.isLoading = false
                    self.errorMessage = bets.isEmpty ? "" : "✅ \(bets.count) bets loaded"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Error: \(error)"
                }
            }
        }
    }
}

struct AdminBetCard: View {
    let bet: Bet
    let onAction: () -> Void
    @State private var isProcessing = false
    @State private var resultText: String = ""
    @State private var showingAlert = false
    @State private var pendingAction: Bool = true // true = approve, false = reject
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(bet.title)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Text("By: \(bet.creatorName)")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            
            if !resultText.isEmpty {
                Text(resultText)
                    .font(.caption)
                    .foregroundColor(resultText.hasPrefix("✅") ? .green : .red)
            }
            
            if !isProcessing {
                HStack(spacing: 12) {
                    Button {
                        pendingAction = true
                        showingAlert = true
                    } label: {
                        Label("Approve", systemImage: "checkmark.circle.fill")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button {
                        pendingAction = false
                        showingAlert = true
                    } label: {
                        Label("Reject", systemImage: "xmark.circle.fill")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            } else {
                ProgressView().tint(AppTheme.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(10)
        .confirmationDialog(
            pendingAction ? "Approve this bet?" : "Reject this bet?",
            isPresented: $showingAlert,
            titleVisibility: .visible
        ) {
            Button(pendingAction ? "Approve" : "Reject", role: pendingAction ? nil : .destructive) {
                moderate(approve: pendingAction)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    func moderate(approve: Bool) {
        guard !isProcessing else { return }
        isProcessing = true
        resultText = ""
        Task {
            do {
                struct SimpleResponse: Decodable { let status: String; let betId: Int?; let action: String? }
                let _: SimpleResponse = try await APIClient.shared.request(
                    "moderator/review.php",
                    method: "POST",
                    body: ["bet_id": bet.id, "action": approve ? "approve" : "reject", "notes": "Moderated via iOS"]
                )
                DispatchQueue.main.async {
                    self.resultText = approve ? "✅ Approved!" : "✅ Rejected!"
                    self.isProcessing = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onAction()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.resultText = "Failed: \(error)"
                    self.isProcessing = false
                }
            }
        }
    }
}
