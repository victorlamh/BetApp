import SwiftUI

struct UserSearchView: View {
    @State private var searchText = ""
    @State private var users: [SearchUser] = []
    @State private var isLoading = false
    @State private var searchError: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.textSecondary)
                        TextField("Search players...", text: $searchText)
                            .foregroundColor(AppTheme.textPrimary)
                            .onChange(of: searchText) { newValue in
                                if newValue.count >= 2 {
                                    searchUsers()
                                }
                            }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(AppTheme.Radius.m)
                    .padding()
                    
                    if isLoading {
                        ProgressView().tint(AppTheme.primary)
                        Spacer()
                    } else if let error = searchError {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Search Error")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                        Spacer()
                    } else if users.isEmpty && !searchText.isEmpty {
                        Text("No players found for \"\(searchText)\"")
                            .foregroundColor(AppTheme.textSecondary)
                            .padding()
                        Spacer()
                    } else {
                        List(users) { user in
                            UserRow(user: user)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Explore")
        }
    }
    
    func searchUsers() {
        isLoading = true
        searchError = nil
        Task {
            do {
                // Build URL safely using URLComponents
                var components = URLComponents(string: "bets/search_users.php")!
                components.queryItems = [URLQueryItem(name: "q", value: searchText)]
                let endpoint = components.string ?? "bets/search_users.php?q=\(searchText)"
                let foundUsers: [SearchUser] = try await APIClient.shared.request(endpoint)
                DispatchQueue.main.async {
                    self.users = foundUsers
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.searchError = error.localizedDescription
                }
            }
        }
    }
}

struct UserRow: View {
    let user: SearchUser
    @State private var status: String?
    @State private var isFollowLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    init(user: SearchUser) {
        self.user = user
        self._status = State(initialValue: user.followStatus)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(AppTheme.cardBackground)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(user.username.prefix(1).uppercased())
                            .foregroundColor(AppTheme.primary)
                    )
            }
            
            VStack(alignment: .leading) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            if status == "accepted" {
                Text("Following")
                    .font(.caption).bold()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.textSecondary.opacity(0.1))
                    .foregroundColor(AppTheme.textSecondary)
                    .cornerRadius(8)
            } else if status == "pending" {
                Text("Requested")
                    .font(.caption).bold()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.primary.opacity(0.1))
                    .foregroundColor(AppTheme.primary)
                    .cornerRadius(8)
            } else {
                Button(action: follow) {
                    if isFollowLoading {
                        ProgressView().tint(.black)
                            .padding(.horizontal, 12)
                    } else {
                        Text("Follow")
                            .font(.caption).bold()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.primary)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                }
                .disabled(isFollowLoading)
            }
        }
        .padding()
        .background(AppTheme.cardBackground.opacity(0.5))
        .cornerRadius(AppTheme.Radius.m)
        .alert("Follow Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func follow() {
        isFollowLoading = true
        Task {
            do {
                struct SimpleRes: Decodable { let status: String }
                let _: SimpleRes = try await APIClient.shared.request(
                    "users/follow.php",
                    method: "POST",
                    body: ["action": "request", "user_id": user.id]
                )
                DispatchQueue.main.async { 
                    self.status = "pending"
                    self.isFollowLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                    self.isFollowLoading = false
                }
            }
        }
    }
}

struct SearchUser: Codable, Identifiable {
    let id: Int
    let username: String
    let displayName: String
    let avatarUrl: String?
    let followStatus: String?
}
