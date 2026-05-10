import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var showingCreateBet = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.m) {
                        // Wallet Header
                        walletHeader
                        
                        if let error = viewModel.errorMessage {
                            VStack {
                                Text("Feed Error").font(.headline)
                                Text(error).font(.caption).multilineTextAlignment(.center)
                                Button("Retry") { Task { await viewModel.fetchFeed() } }
                                    .padding(.top, 4)
                            }
                            .foregroundColor(.red)
                            .padding()
                        }
                        
                        // Bets List
                        if viewModel.isLoading && viewModel.bets.isEmpty {
                            ProgressView()
                                .tint(AppTheme.primary)
                                .padding()
                        } else if viewModel.bets.isEmpty && viewModel.errorMessage == nil {
                            Text("No live bets found")
                                .foregroundColor(AppTheme.textSecondary)
                                .padding()
                        } else {
                            ForEach(viewModel.bets) { bet in
                                NavigationLink(destination: BetDetailView(betId: bet.id)) {
                                    BetCard(bet: bet)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.fetchFeed()
                }
            }
            .navigationTitle("Bets Feed")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateBet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
            .sheet(isPresented: $showingCreateBet) {
                CreateBetView()
            }
        }
        .task {
            await viewModel.fetchFeed()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
    
    private var walletHeader: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Circle()
                .fill(AppTheme.primary.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "wallet.pass.fill").foregroundColor(AppTheme.primary))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AVAILABLE BALANCE")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(AppTheme.textSecondary)
                Text("\(String(format: "%.2f", viewModel.balance))€")
                    .font(.title3.bold())
                    .foregroundColor(AppTheme.textPrimary)
            }
            Spacer()
        }
        .padding()
        .background(Color.black)
        .cornerRadius(AppTheme.Radius.m)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
        )
    }
}

class FeedViewModel: ObservableObject {
    @Published var bets: [Bet] = []
    @Published var balance: Double = 0.0
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private var timer: Timer?
    
    func fetchFeed() async {
        DispatchQueue.main.async { 
            self.isLoading = true 
            self.errorMessage = nil
        }
        do {
            let fetchedBets: [Bet] = try await APIClient.shared.request("bets/feed.php")
            struct WalletResponse: Decodable { let walletBalance: Double }
            let wallet: WalletResponse = try await APIClient.shared.request("auth/me.php")
            
            DispatchQueue.main.async {
                self.bets = fetchedBets
                self.balance = wallet.walletBalance
                self.isLoading = false
            }
        } catch {
            print("Feed error: \(error)")
            DispatchQueue.main.async { 
                self.isLoading = false 
                self.errorMessage = "\(error)"
            }
        }
    }
    
    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in
            Task { await self.fetchFeed() }
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}

struct BetCard: View {
    let bet: Bet
    @State private var timeRemaining: String = ""
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(displayStatusLabel)
                        .font(.system(size: 10, weight: .black))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor)
                .foregroundColor(.black)
                .cornerRadius(4)
                
                if bet.status == "live" {
                    Text(timeRemaining)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(timeRemaining.contains("!") ? .orange : AppTheme.textSecondary)
                        .onReceive(timer) { _ in updateTimeRemaining() }
                }
                
                Spacer()
                
                Text("@\(bet.creatorName)")
                    .font(.caption2).bold()
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Text(bet.title)
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)
            
            // Odds
            HStack(spacing: 8) {
                if let outcomes = bet.outcomes {
                    let minCoeff = outcomes.map { $0.coefficient }.min() ?? 0
                    
                    ForEach(outcomes.prefix(2)) { outcome in
                        HStack {
                            Text(outcome.label)
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text(String(format: "%.2f", outcome.coefficient))
                                .font(.system(.subheadline, design: .monospaced))
                                .bold()
                                .foregroundColor(outcome.coefficient == minCoeff ? AppTheme.oddsUp : AppTheme.primary)
                        }
                        .padding(12)
                        .background(AppTheme.secondary.opacity(0.4))
                        .cornerRadius(AppTheme.Radius.s)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.m)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                .stroke(isLocked ? Color.orange.opacity(0.5) : AppTheme.primary.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.8), radius: 10, y: 5)
        .onAppear { updateTimeRemaining() }
    }
    
    private func updateTimeRemaining() {
        let diff = bet.closeDate.timeIntervalSince(Date())
        if diff <= 0 {
            timeRemaining = "CLOSED"
        } else {
            let hours = Int(diff) / 3600
            let minutes = (Int(diff) % 3600) / 60
            let seconds = Int(diff) % 60
            
            if hours > 0 {
                timeRemaining = String(format: "ENDS IN: %02dh %02dm", hours, minutes)
            } else {
                timeRemaining = String(format: "ENDS IN: %02d:%02d", minutes, seconds)
                if minutes < 10 { timeRemaining += "!" }
            }
        }
    }
    
    private var isLocked: Bool {
        bet.status == "live" && bet.closeDate <= Date()
    }
    
    private var displayStatusLabel: String {
        if isLocked { return "LOCKED" }
        return bet.statusLabel
    }
    
    private var statusColor: Color {
        if isLocked { return Color.orange }
        switch bet.status {
        case "live": return AppTheme.accent
        case "locked": return Color.orange
        case "settled": return AppTheme.primary
        case "void": return AppTheme.textSecondary
        default: return AppTheme.textSecondary
        }
    }
}
