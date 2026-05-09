import SwiftUI

struct ProfileView: View {
    @ObservedObject var authStore = AuthStore.shared
    @State private var followersCount = 0
    @State private var followingCount = 0
    @State private var walletBalance: Double = 0.0
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.xl) {
                        // Header: Avatar & Info
                        VStack(spacing: AppTheme.Spacing.m) {
                            Circle()
                                .fill(AppTheme.cardBackground)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.primary)
                                )
                                .shadow(color: AppTheme.primary.opacity(0.2), radius: 10)
                            
                            VStack(spacing: 4) {
                                Text(authStore.currentUser?.displayName ?? "User")
                                    .font(.title2).bold()
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("@\(authStore.currentUser?.username ?? "username")")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        
                        // Stats Row
                        HStack(spacing: 40) {
                            StatItem(label: "Followers", value: "\(followersCount)")
                            StatItem(label: "Following", value: "\(followingCount)")
                            StatItem(label: "Balance", value: String(format: "%.2f€", walletBalance))
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.Radius.m)
                        
                        // Actions section
                        VStack(spacing: AppTheme.Spacing.m) {
                            ProfileButton(label: "Edit Profile", icon: "pencil")
                            ProfileButton(label: "Wallet History", icon: "list.bullet.rectangle")
                            ProfileButton(label: "Security", icon: "lock.shield")
                            
                            Button(action: { authStore.logout() }) {
                                Label("Logout", systemImage: "arrow.right.square")
                                    .foregroundColor(AppTheme.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(AppTheme.cardBackground)
                                    .cornerRadius(AppTheme.Radius.m)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .onAppear(perform: fetchProfileStats)
        }
    }
    
    func fetchProfileStats() {
        // We'll simulate for now, but usually this hits a users/me.php endpoint
        Task {
            do {
                struct ProfileData: Decodable {
                    let followersCount: Int
                    let followingCount: Int
                    let walletBalance: Double
                }
                // In a real app, we'd hit the API here
                // For now, let's just use the current balance from login if available
                DispatchQueue.main.async {
                    self.walletBalance = 100.0 // Placeholder
                    self.followersCount = 12
                    self.followingCount = 45
                }
            }
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(AppTheme.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

struct ProfileButton: View {
    let label: String
    let icon: String
    
    var body: some View {
        Button(action: {}) {
            Label(label, systemImage: icon)
                .foregroundColor(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.Radius.m)
        }
    }
}
