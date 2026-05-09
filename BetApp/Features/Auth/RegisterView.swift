import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = RegisterViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: AppTheme.Spacing.l) {
                Text("Join the Game")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(AppTheme.textPrimary)
                
                VStack(spacing: AppTheme.Spacing.m) {
                    TextField("Username", text: $viewModel.username)
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.Radius.m)
                        .foregroundColor(AppTheme.textPrimary)
                        .autocapitalization(.none)
                    
                    TextField("Display Name", text: $viewModel.displayName)
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.Radius.m)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    SecureField("Password", text: $viewModel.password)
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.Radius.m)
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppTheme.danger)
                }
                
                Button(action: {
                    Task { await viewModel.register() }
                }) {
                    if viewModel.isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Text("CREATE ACCOUNT")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(AppTheme.primary)
                .cornerRadius(AppTheme.Radius.m)
                .disabled(viewModel.isLoading)
                
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(AppTheme.textSecondary)
                
                Spacer()
            }
            .padding()
        }
    }
}

class RegisterViewModel: ObservableObject {
    @Published var username = ""
    @Published var displayName = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func register() async {
        guard !username.isEmpty && !password.isEmpty && !displayName.isEmpty else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            struct RegisterResponse: Decodable {
                let token: String
                let user: User
            }
            
            let response: RegisterResponse = try await APIClient.shared.request(
                "auth/register.php",
                method: "POST",
                body: [
                    "username": username,
                    "display_name": displayName,
                    "password": password
                ]
            )
            
            DispatchQueue.main.async {
                AuthStore.shared.login(token: response.token, user: response.user)
                self.isLoading = false
            }
        } catch let error as APIError {
            DispatchQueue.main.async {
                self.isLoading = false
                switch error {
                case .serverError(let message):
                    self.errorMessage = message
                default:
                    self.errorMessage = "Network error. Please try again."
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "An unexpected error occurred."
            }
        }
    }
}
