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
                        
                        // Section: Outcomes
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                            HStack {
                                Text("OUTCOMES")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.textSecondary)
                                Spacer()
                                Button(action: addOutcome) {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(AppTheme.primary)
                                }
                            }
                            
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
                        }
                        
                        // Section: Date
                        DatePicker("Close Betting At", selection: $closeDate, in: Date()...)
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(AppTheme.Radius.m)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(AppTheme.danger)
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
        outcomes.append(OutcomeInput(label: "", coefficient: "2.00"))
    }
    
    private func submitBet() {
        isLoading = true
        errorMessage = nil
        
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        
        let body: [String: Any] = [
            "title": title,
            "description": description,
            "close_at": formatter.string(from: closeDate),
            "outcomes": outcomes.map { ["label": $0.label, "coefficient": Double($0.coefficient) ?? 1.0] }
        ]
        
        Task {
            do {
                struct CreateResponse: Decodable { let status: String }
                let _: CreateResponse = try await APIClient.shared.request(
                    "bets/create.php",
                    method: "POST",
                    body: body
                )
                
                DispatchQueue.main.async {
                    isLoading = false
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Failed to create bet. Check your inputs."
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
