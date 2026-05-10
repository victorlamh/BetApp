import SwiftUI

struct WagerSlipView: View {
    let betId: Int
    let outcome: BetOutcome
    let onCompletion: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var stake: String = "10"
    @State private var userBalance: Double?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var potentialReturn: Double {
        let amount = Double(stake) ?? 0
        return amount * outcome.coefficient
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: AppTheme.Spacing.l) {
                    // Outcome Info
                    VStack(spacing: AppTheme.Spacing.s) {
                        Text("PLACING WAGER ON")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                        Text(outcome.label)
                            .font(.title3)
                            .bold()
                            .foregroundColor(AppTheme.textPrimary)
                        Text("@ \(String(format: "%.2f", outcome.coefficient))")
                            .font(.headline)
                            .foregroundColor(AppTheme.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(AppTheme.Radius.m)
                    
                    // Stake Input
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                        HStack {
                            Text("STAKE AMOUNT")
                                .font(.caption).bold()
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            if let balance = userBalance {
                                Text("Balance: \(String(format: "%.2f", balance))€")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        
                        HStack {
                            Text("€")
                                .font(.title.bold())
                                .foregroundColor(AppTheme.primary)
                            TextField("0.00", text: $stake)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .padding()
                        .background(AppTheme.secondary)
                        .cornerRadius(AppTheme.Radius.m)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.m)
                                .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
                        )
                        
                        // Quick Amounts
                        HStack(spacing: 8) {
                            ForEach([1, 2, 5, 10], id: \.self) { amount in
                                Button(action: { stake = "\(amount)" }) {
                                    Text("\(amount)€")
                                        .font(.subheadline).bold()
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(stake == "\(amount)" ? AppTheme.primary : AppTheme.secondary)
                                        .foregroundColor(stake == "\(amount)" ? .black : .white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Button(action: {
                                if let balance = userBalance {
                                    stake = String(format: "%.2f", balance)
                                }
                            }) {
                                Text("MAX")
                                    .font(.subheadline).bold()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.secondary)
                                    .foregroundColor(AppTheme.primary)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.primary.opacity(0.5), lineWidth: 1))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Summary
                    VStack(spacing: AppTheme.Spacing.m) {
                        HStack {
                            Text("Potential Return")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text("\(String(format: "%.2f", potentialReturn))€")
                                .font(.title3)
                                .bold()
                                .foregroundColor(AppTheme.oddsUp)
                        }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(AppTheme.Radius.m)
                    
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                        }
                        .font(.caption)
                        .foregroundColor(AppTheme.oddsDown)
                        .padding()
                        .background(AppTheme.oddsDown.opacity(0.1))
                        .cornerRadius(AppTheme.Radius.s)
                    }
                    
                    Spacer()
                    
                    Button(action: placeWager) {
                        ZStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("CONFIRM WAGER (\(stake)€)")
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppTheme.oddsDown) // Use red-ish for the main button like in image
                        .cornerRadius(AppTheme.Radius.m)
                        .shadow(color: AppTheme.oddsDown.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isLoading || (Double(stake) ?? 0) <= 0)
                }
                .padding()
            }
            .navigationTitle("Wager Slip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .onAppear(perform: fetchBalance)
        }
    }
    
    private func fetchBalance() {
        Task {
            do {
                struct WalletResponse: Decodable { let walletBalance: Double }
                let res: WalletResponse = try await APIClient.shared.request("auth/me.php")
                DispatchQueue.main.async {
                    self.userBalance = res.walletBalance
                }
            } catch {
                print("Failed to fetch balance: \(error)")
            }
        }
    }
    
    private func placeWager() {
        guard let amount = Double(stake), amount > 0 else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                struct WagerResponse: Decodable {
                    let newBalance: Double
                    let potentialReturn: Double
                }
                let _: WagerResponse = try await APIClient.shared.request(
                    "wagers/place.php",
                    method: "POST",
                    body: [
                        "bet_id": betId,
                        "outcome_id": outcome.id,
                        "stake": amount
                    ]
                )
                
                DispatchQueue.main.async {
                    isLoading = false
                    onCompletion()
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .serverError(let msg):
                            self.errorMessage = msg
                        default:
                            self.errorMessage = "Network or server error"
                        }
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
