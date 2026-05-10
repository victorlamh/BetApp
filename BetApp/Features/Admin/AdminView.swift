import SwiftUI

struct AdminView: View {
    @ObservedObject var authStore = AuthStore.shared
    @State private var bets: [Bet] = []
    @State private var selectedTab = 0 // 0: Pending, 1: Live
    @State private var isLoading = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                if authStore.currentUser?.role != "admin" && authStore.currentUser?.role != "moderator" {
                    VStack {
                        Image(systemName: "lock.shield").font(.largeTitle).foregroundColor(AppTheme.textSecondary)
                        Text("Moderator access only").foregroundColor(AppTheme.textSecondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        Picker("Status", selection: $selectedTab) {
                            Text("Pending").tag(0)
                            Text("Live").tag(1)
                            Text("To Settle").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        .background(AppTheme.background)
                        
                        // Status bar
                        let statusText = selectedTab == 0 ? "Pending" : (selectedTab == 1 ? "Live" : "To Settle")
                        HStack {
                            Text("\(statusText): \(bets.count)")
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
                        } else if bets.isEmpty {
                            Spacer()
                            Text("No bets to show").foregroundColor(AppTheme.textSecondary)
                            Spacer()
                        } else {
                            List(bets) { bet in
                                if selectedTab == 0 {
                                    AdminBetCard(bet: bet, onAction: fetchBets)
                                } else if selectedTab == 1 {
                                    AdminLiveBetCard(bet: bet, onAction: fetchBets)
                                } else {
                                    AdminSettleCard(bet: bet, onAction: fetchBets)
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 4)
                            .listStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Admin Panel")
            .onChange(of: selectedTab) { _, _ in fetchBets() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: fetchBets) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                if authStore.currentUser?.role == "admin" {
                    fetchBets()
                }
            }
        }
    }
    
    func fetchBets() {
        isLoading = true
        errorMessage = ""
        let status: String
        switch selectedTab {
        case 0: status = "pending_review"
        case 1: status = "live"
        case 2: status = "locked,result_proposed,live" // To settle
        default: status = "live"
        }
        
        Task {
            do {
                let fetched: [Bet] = try await APIClient.shared.request("bets/list.php?status=\(status)")
                DispatchQueue.main.async {
                    self.bets = fetched
                    self.isLoading = false
                    self.errorMessage = fetched.isEmpty ? "" : "✅ \(fetched.count) bets loaded"
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
    @State private var showingConfirmation = false
    @State private var isApproveAction = true
    
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
                        isApproveAction = true
                        showingConfirmation = true
                    } label: {
                        Label("Approve", systemImage: "checkmark.circle.fill")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button {
                        isApproveAction = false
                        showingConfirmation = true
                    } label: {
                        Label("Reject", systemImage: "xmark.circle.fill")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
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
            isApproveAction ? "Approve this bet?" : "Reject this bet?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button(isApproveAction ? "Yes, Approve" : "Yes, Reject", role: isApproveAction ? nil : .destructive) {
                moderate(approve: isApproveAction)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    func moderate(approve: Bool) {
        guard !isProcessing else { return }
        isProcessing = true
        resultText = ""
        
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        
        Task {
            do {
                struct SimpleResponse: Decodable { let status: String; let betId: Int?; let action: String? }
                let _: SimpleResponse = try await APIClient.shared.request(
                    "moderator/review.php",
                    method: "POST",
                    body: ["bet_id": bet.id, "action": approve ? "approve" : "reject", "notes": "Moderated via iOS"]
                )
                DispatchQueue.main.async {
                    generator.notificationOccurred(.success)
                    self.resultText = approve ? "✅ Approved!" : "✅ Rejected!"
                    self.isProcessing = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        onAction()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    generator.notificationOccurred(.error)
                    self.resultText = "Failed: \(error)"
                    self.isProcessing = false
                }
            }
        }
    }
}

struct AdminLiveBetCard: View {
    let bet: Bet
    let onAction: () -> Void
    @State private var isProcessing = false
    @State private var resultText: String = ""
    @State private var showingConfirmation = false
    @State private var isDeleteAction = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bet.title)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("By: \(bet.creatorName)")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
                Text("LIVE")
                    .font(.caption2)
                    .bold()
                    .padding(4)
                    .background(AppTheme.oddsUp.opacity(0.2))
                    .foregroundColor(AppTheme.oddsUp)
                    .cornerRadius(4)
            }
            
            if !resultText.isEmpty {
                Text(resultText)
                    .font(.caption)
                    .foregroundColor(resultText.hasPrefix("✅") ? .green : .red)
            }
            
            if !isProcessing {
                HStack(spacing: 12) {
                    Button {
                        isDeleteAction = true
                        showingConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                            .font(.caption)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button {
                        isDeleteAction = false
                        showingConfirmation = true
                    } label: {
                        Label("Void", systemImage: "slash.circle")
                            .font(.caption)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
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
            isDeleteAction ? "Delete this bet? (All users refunded)" : "Void this bet? (Mark as canceled, users refunded)",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button(isDeleteAction ? "Delete & Refund" : "Void & Refund", role: .destructive) {
                performAction(action: isDeleteAction ? "delete" : "void")
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    func performAction(action: String) {
        guard !isProcessing else { return }
        isProcessing = true
        resultText = ""
        
        Task {
            do {
                struct SimpleResponse: Decodable { let status: String }
                let _: SimpleResponse = try await APIClient.shared.request(
                    "admin/manage_bet.php",
                    method: "POST",
                    body: [
                        "bet_id": bet.id,
                        "action": action,
                        "reason": "Admin action via iOS"
                    ]
                )
                DispatchQueue.main.async {
                    self.resultText = "✅ Success!"
                    self.isProcessing = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
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

struct AdminSettleCard: View {
    let bet: Bet
    let onAction: () -> Void
    @State private var isProcessing = false
    @State private var resultText: String = ""
    @State private var showingConfirmation = false
    @State private var selectedOutcome: BetOutcome?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(bet.title)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Created by: \(bet.creatorName)")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Text("Select Winner:")
                .font(.caption)
                .bold()
                .foregroundColor(AppTheme.primary)
            
            ForEach(bet.outcomes ?? []) { outcome in
                Button {
                    selectedOutcome = outcome
                } label: {
                    HStack {
                        Text(outcome.label)
                        Spacer()
                        if selectedOutcome?.id == outcome.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(8)
                    .background(selectedOutcome?.id == outcome.id ? Color.green.opacity(0.1) : AppTheme.secondary)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if !resultText.isEmpty {
                Text(resultText)
                    .font(.caption)
                    .foregroundColor(resultText.hasPrefix("✅") ? .green : .red)
            }
            
            if !isProcessing {
                Button {
                    showingConfirmation = true
                } label: {
                    Text("SETTLE BET")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedOutcome == nil ? Color.gray : Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                .disabled(selectedOutcome == nil)
            } else {
                ProgressView().tint(AppTheme.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(10)
        .confirmationDialog(
            "Settle bet with outcome: \(selectedOutcome?.label ?? "")?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes, Settle & Payout") {
                settle()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    func settle() {
        guard let outcome = selectedOutcome, !isProcessing else { return }
        isProcessing = true
        resultText = ""
        
        Task {
            do {
                struct SimpleResponse: Decodable { let status: String }
                let _: SimpleResponse = try await APIClient.shared.request(
                    "admin/settle_bet.php",
                    method: "POST",
                    body: [
                        "bet_id": bet.id,
                        "winning_outcome_id": outcome.id
                    ]
                )
                DispatchQueue.main.async {
                    self.resultText = "✅ Payouts Distributed!"
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
