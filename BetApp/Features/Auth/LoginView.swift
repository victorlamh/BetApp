import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var showingRegister = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: AppTheme.Spacing.xl) {
                    // Logo/Header
                    VStack(spacing: AppTheme.Spacing.s) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.primary)
                        Text("BET APP")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Private Social Betting")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.top, 50)
                    
                    VStack(spacing: AppTheme.Spacing.m) {
                        TextField("Username", text: $viewModel.username)
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(AppTheme.Radius.m)
                            .foregroundColor(AppTheme.textPrimary)
                            .autocapitalization(.none)
                        
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
                        Task { await viewModel.login() }
                    }) {
                        if viewModel.isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("LOGIN")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(AppTheme.primary)
                    .cornerRadius(AppTheme.Radius.m)
                    .disabled(viewModel.isLoading)
                    
                    Button("Don't have an account? Register") {
                        showingRegister = true
                    }
                    .foregroundColor(AppTheme.primary)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingRegister) {
                RegisterView()
            }
        }
    }
}

class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func login() async {
        guard !username.isEmpty && !password.isEmpty else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            struct LoginResponse: Decodable {
                let token: String
                let user: User
            }
            
            let response: LoginResponse = try await APIClient.shared.request(
                "auth/login.php",
                method: "POST",
                body: ["username": username, "password": password]
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
                    self.errorMessage = "Invalid login. Please check your credentials."
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
