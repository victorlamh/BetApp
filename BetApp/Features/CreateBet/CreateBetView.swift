import SwiftUI

struct CreateBetView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var closeDate = Date().addingTimeInterval(86400)
    @State private var outcomes: [OutcomeInput] = [
        OutcomeInput(label: "Yes", coefficient: "2.00"),
        OutcomeInput(label: "No", coefficient: "2.00")
    ]
    @State private var useSlider: Bool = true
    @State private var probability: Double = 0.5 // 50%
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                        // Section: Question
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                            Text("THE QUESTION")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                            TextField("e.g. Will it rain tomorrow?", text: $title)
                                .padding()
                                .background(AppTheme.cardBackground)
                                .cornerRadius(AppTheme.Radius.m)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        
                        // Section: Odds Mode Toggle
                        HStack {
                            Text("SET THE ODDS")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Picker("Mode", selection: $useSlider) {
                                Text("Simple").tag(true)
                                Text("Manual").tag(false)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 150)
                        }
                        
                        if useSlider && outcomes.count == 2 {
                            // Section: Smart Slider
                            VStack(spacing: AppTheme.Spacing.m) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(outcomes[0].label)
                                            .font(.headline)
                                        Text("\(String(format: "%.2f", 1.0 / probability))x")
                                            .foregroundColor(AppTheme.primary)
                                            .font(.title2).bold()
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text(outcomes[1].label)
                                            .font(.headline)
                                        Text("\(String(format: "%.2f", 1.0 / (1.0 - probability)))x")
                                            .foregroundColor(AppTheme.primary)
                                            .font(.title2).bold()
                                    }
                                }
                                
                                Slider(value: $probability, in: 0.05...0.95)
                                    .tint(AppTheme.primary)
                                
                                Text("Slide to set the favorite. Center is 50/50.")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(AppTheme.Radius.m)
                        } else {
                            // Section: Manual Outcomes
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                                ForEach($outcomes) { $outcome in
                                    HStack {
                                        TextField("Label", text: $outcome.label)
                                            .padding()
                                            .background(AppTheme.cardBackground)
                                            .cornerRadius(AppTheme.Radius.s)
                                        
                                        TextField("Odds", text: $outcome.coefficient)
                                            .keyboardType(.decimalPad)
                                            .frame(width: 80)
                                            .padding()
                                            .background(AppTheme.cardBackground)
                                            .cornerRadius(AppTheme.Radius.s)
                                    }
                                }
                                
                                if outcomes.count < 5 {
                                    Button(action: addOutcome) {
                                        Label("Add Outcome", systemImage: "plus.circle")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.primary)
                                    }
                                    .padding(.top, 5)
                                }
                            }
                        }
                        
                        // Section: Date
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                            Text("BETTING CLOSES AT")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                            DatePicker("", selection: $closeDate, in: Date()...)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.cardBackground)
                                .cornerRadius(AppTheme.Radius.m)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(AppTheme.danger)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        Button(action: submitBet) {
                            if isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("SUBMIT FOR REVIEW")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(AppTheme.primary)
                        .cornerRadius(AppTheme.Radius.m)
                        .disabled(isLoading || title.isEmpty)
                        .padding(.top, 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Bet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func addOutcome() {
        outcomes.append(OutcomeInput(label: "Outcome \(outcomes.count + 1)", coefficient: "2.00"))
        useSlider = false // Force manual if more than 2 outcomes
    }
    
    private func submitBet() {
        isLoading = true
        errorMessage = nil
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Send as UTC
        
        // Final coefficients calculation
        var finalOutcomes: [[String: Any]] = []
        if useSlider && outcomes.count == 2 {
            finalOutcomes = [
                ["label": outcomes[0].label, "coefficient": 1.0 / probability],
                ["label": outcomes[1].label, "coefficient": 1.0 / (1.0 - probability)]
            ]
        } else {
            finalOutcomes = outcomes.map { ["label": $0.label, "coefficient": Double($0.coefficient) ?? 2.0] }
        }
        
        let body: [String: Any] = [
            "title": title,
            "description": description,
            "close_at": formatter.string(from: closeDate),
            "outcomes": finalOutcomes
        ]
        
        Task {
            do {
                struct CreateResponse: Decodable { let betId: Int }
                let _: CreateResponse = try await APIClient.shared.request(
                    "bets/create.php",
                    method: "POST",
                    body: body
                )
                
                DispatchQueue.main.async {
                    isLoading = false
                    dismiss()
                }
            } catch let error as APIError {
                DispatchQueue.main.async {
                    isLoading = false
                    switch error {
                    case .serverError(let msg): self.errorMessage = msg
                    default: self.errorMessage = "Check your connection and try again."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    self.errorMessage = "Failed to create bet."
                }
            }
        }
    }
}

struct OutcomeInput: Identifiable {
    let id = UUID()
    var label: String
    var coefficient: String
}
