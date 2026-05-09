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
                        
                        // Bets List
                        if viewModel.isLoading && viewModel.bets.isEmpty {
                            ProgressView()
                                .tint(AppTheme.primary)
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
        HStack {
            VStack(alignment: .leading) {
                Text("Your Balance")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Text("\(String(format: "%.2f", viewModel.balance))€")
                    .font(.title2)
                    .bold()
                    .foregroundColor(AppTheme.textPrimary)
            }
            Spacer()
            Image(systemName: "wallet.pass.fill")
                .font(.title)
                .foregroundColor(AppTheme.primary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.m)
    }
}

class FeedViewModel: ObservableObject {
    @Published var bets: [Bet] = []
    @Published var balance: Double = 0.0
    @Published var isLoading = false
    
    private var timer: Timer?
    
    func fetchFeed() async {
        DispatchQueue.main.async { self.isLoading = true }
        do {
            let fetchedBets: [Bet] = try await APIClient.shared.request("bets/feed.php")
            // Also fetch wallet
            struct WalletResponse: Decodable { let walletBalance: Double }
            let wallet: WalletResponse = try await APIClient.shared.request("auth/me.php")
            
            DispatchQueue.main.async {
                self.bets = fetchedBets
                self.balance = wallet.walletBalance
                self.isLoading = false
            }
        } catch {
            print("Feed error: \(error)")
            DispatchQueue.main.async { self.isLoading = false }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack {
                Text(bet.statusLabel)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
                
                Spacer()
                
                Text(bet.creatorName)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Text(bet.title)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)
            
            HStack {
                ForEach(bet.outcomes.prefix(2)) { outcome in
                    HStack {
                        Text(outcome.label)
                        Spacer()
                        Text(String(format: "%.2f", outcome.coefficient))
                            .bold()
                    }
                    .font(.caption)
                    .padding(8)
                    .background(AppTheme.secondary)
                    .cornerRadius(AppTheme.Radius.s)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.m)
    }
    
    private var statusColor: Color {
        switch bet.status {
        case "live": return AppTheme.accent
        case "locked": return Color.orange
        case "settled": return AppTheme.primary
        case "void": return AppTheme.textSecondary
        default: return AppTheme.textSecondary
        }
    }
}
