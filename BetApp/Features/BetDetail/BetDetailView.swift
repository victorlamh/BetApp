import SwiftUI

struct BetDetailView: View {
    let betId: Int
    @StateObject private var viewModel: BetDetailViewModel
    @State private var showingWagerSlip = false
    @State private var selectedOutcome: BetOutcome?
    
    init(betId: Int) {
        self.betId = betId
        _viewModel = StateObject(wrappedValue: BetDetailViewModel(betId: betId))
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()
            
            if let bet = viewModel.bet {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                        headerSection(bet)
                        
                        Text(bet.description ?? "No description provided.")
                            .foregroundColor(AppTheme.textSecondary)
                        
                        outcomesSection(bet)
                        
                        if let wager = bet.myWager {
                            myWagerSection(wager)
                        }
                        
                        if bet.status == "result_proposed" {
                            validationSection(bet)
                        }
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            } else if viewModel.isLoading {
                ProgressView().tint(AppTheme.primary)
            }
            
            if let bet = viewModel.bet, bet.status == "live", bet.myWager == nil {
                wagerButton
            }
        }
        .navigationTitle("Bet Details")
        .sheet(isPresented: $showingWagerSlip) {
            if let outcome = selectedOutcome {
                WagerSlipView(betId: betId, outcome: outcome) {
                    Task { await viewModel.fetchDetails() }
                }
            }
        }
        .task {
            await viewModel.fetchDetails()
        }
    }
    
    private func headerSection(_ bet: Bet) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(statusColor(bet.status)).frame(width: 6, height: 6)
                    Text(bet.statusLabel)
                        .font(.caption).bold()
                }
                .padding(6)
                .background(statusColor(bet.status).opacity(0.1))
                .foregroundColor(statusColor(bet.status))
                .cornerRadius(4)
                
                Spacer()
                
                if bet.status == "live" {
                    CountdownText(date: bet.closeDate)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(AppTheme.textSecondary)
                } else {
                    Text("Closed \(bet.localizedCloseAt)")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            Text(bet.title)
                .font(.title)
                .bold()
                .foregroundColor(AppTheme.textPrimary)
            
            Text("Created by \(bet.creatorName)")
                .font(.subheadline)
                .foregroundColor(AppTheme.primary)
        }
    }
    
    private func outcomesSection(_ bet: Bet) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            Text("Outcomes")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            ForEach(bet.outcomes ?? []) { outcome in
                Button(action: {
                    if bet.status == "live" && bet.myWager == nil {
                        selectedOutcome = outcome
                        showingWagerSlip = true
                    }
                }) {
                    HStack {
                        Text(outcome.label)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text(String(format: "%.2f", outcome.coefficient))
                            .font(.system(.title3, design: .monospaced))
                            .bold()
                            .foregroundColor(selectedOutcome?.id == outcome.id ? .black : AppTheme.oddsUp)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedOutcome?.id == outcome.id ? AppTheme.oddsUp : AppTheme.oddsUp.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                            .stroke(selectedOutcome?.id == outcome.id ? AppTheme.oddsUp : Color.clear, lineWidth: 2)
                    )
                    .cornerRadius(AppTheme.Radius.m)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(bet.status != "live" || bet.myWager != nil)
            }
        }
    }
    
    private func myWagerSection(_ wager: Wager) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Your Wager")
                .font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Text("Stake: \(String(format: "%.2f", wager.stake))€")
                    Text("Potential Return: \(String(format: "%.2f", wager.potentialReturn))€")
                }
                Spacer()
                Text(wager.status.uppercased())
                    .bold()
                    .foregroundColor(wager.status == "active" ? .orange : (wager.status == "won" ? .green : .red))
            }
            .padding()
            .background(AppTheme.secondary)
            .cornerRadius(AppTheme.Radius.m)
        }
    }
    
    private func validationSection(_ bet: Bet) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            Divider().background(AppTheme.textSecondary)
            Text("Validate Result")
                .font(.headline)
            
            Text("The creator has proposed a winning outcome. Please validate.")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            
            HStack(spacing: AppTheme.Spacing.m) {
                Button("Approve") {
                    Task { await viewModel.vote(approve: true) }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accent)
                .foregroundColor(.white)
                .cornerRadius(AppTheme.Radius.m)
                
                Button("Reject") {
                    Task { await viewModel.vote(approve: false) }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.danger)
                .foregroundColor(.white)
                .cornerRadius(AppTheme.Radius.m)
            }
        }
    }
    
    private var wagerButton: some View {
        Button(action: {
            if let first = viewModel.bet?.outcomes?.first {
                selectedOutcome = first
                showingWagerSlip = true
            }
        }) {
            Text("PLACE WAGER")
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.primary)
                .cornerRadius(AppTheme.Radius.m)
                .padding()
        }
    }
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "live": return AppTheme.accent
        case "locked": return Color.orange
        case "settled": return AppTheme.primary
        case "void": return AppTheme.textSecondary
        default: return AppTheme.textSecondary
        }
    }
}

class BetDetailViewModel: ObservableObject {
    let betId: Int
    @Published var bet: Bet?
    @Published var isLoading = false
    
    init(betId: Int) {
        self.betId = betId
    }
    
    func fetchDetails() async {
        DispatchQueue.main.async { self.isLoading = true }
        do {
            let fetchedBet: Bet = try await APIClient.shared.request("bets/detail.php?id=\(betId)")
            DispatchQueue.main.async {
                self.bet = fetchedBet
                self.isLoading = false
            }
        } catch {
            print("Detail error: \(error)")
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
    
    func vote(approve: Bool) async {
        do {
            struct VoteResponse: Decodable { let status: String }
            let _: VoteResponse = try await APIClient.shared.request(
                "bets/validate_result.php",
                method: "POST",
                body: [
                    "bet_id": betId,
                    "proposal_id": 1, // Simplified
                    "vote": approve ? "approve" : "reject"
                ]
            )
            await fetchDetails()
        } catch {
            print("Vote error: \(error)")
        }
    }
}

struct CountdownText: View {
    let date: Date
    @State private var text: String = ""
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(text)
            .onAppear(perform: update)
            .onReceive(timer) { _ in update() }
    }
    
    private func update() {
        let diff = date.timeIntervalSince(Date())
        if diff <= 0 {
            text = "CLOSED"
        } else {
            let h = Int(diff) / 3600
            let m = (Int(diff) % 3600) / 60
            let s = Int(diff) % 60
            if h > 0 {
                text = String(format: "%02dh %02dm", h, m)
            } else {
                text = String(format: "%02d:%02d", m, s)
            }
        }
    }
}
