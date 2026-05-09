import SwiftUI

struct WagerSlipView: View {
    let betId: Int
    let outcome: BetOutcome
    let onCompletion: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var stake: String = "10"
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
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                        Text("STAKE AMOUNT (€)")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        TextField("0.00", text: $stake)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(AppTheme.secondary)
                            .cornerRadius(AppTheme.Radius.m)
                    }
                    
                    // Summary
                    HStack {
                        Text("Potential Return")
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text("\(String(format: "%.2f", potentialReturn))€")
                            .font(.headline)
                            .foregroundColor(AppTheme.accent)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(AppTheme.Radius.m)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppTheme.danger)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    Button(action: placeWager) {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("CONFIRM WAGER")
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.primary)
                    .cornerRadius(AppTheme.Radius.m)
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
        }
    }
    
    private func placeWager() {
        guard let amount = Double(stake), amount > 0 else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                struct WagerResponse: Decodable { let status: String }
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
                    isLoading = false
                    errorMessage = "Failed to place wager. Check your balance."
                }
            }
        }
    }
}
