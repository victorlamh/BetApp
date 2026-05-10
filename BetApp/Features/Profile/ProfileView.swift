import SwiftUI
import PhotosUI

struct ProfileView: View {
    @ObservedObject var authStore = AuthStore.shared
    @State private var followersCount = 0
    @State private var followingCount = 0
    @State private var walletBalance: Double = 0.0
    @State private var statPoints: [StatPoint] = []
    @State private var isLoading = true
    
    // Avatar Upload
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView().tint(AppTheme.primary)
                } else {
                    ScrollView {
                        VStack(spacing: AppTheme.Spacing.xl) {
                            
                            // Header: Avatar & Info
                            VStack(spacing: AppTheme.Spacing.m) {
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    ZStack {
                                        if let avatarUrl = authStore.currentUser?.avatarUrl, let url = URL(string: avatarUrl) {
                                            AsyncImage(url: url) { image in
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                ProgressView()
                                            }
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(AppTheme.cardBackground)
                                                .frame(width: 100, height: 100)
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 40))
                                                        .foregroundColor(AppTheme.primary)
                                                )
                                        }
                                        
                                        if isUploading {
                                            Circle()
                                                .fill(Color.black.opacity(0.5))
                                                .frame(width: 100, height: 100)
                                                .overlay(ProgressView().tint(.white))
                                        }
                                        
                                        // Edit icon overlay
                                        Circle()
                                            .fill(AppTheme.primary)
                                            .frame(width: 30, height: 30)
                                            .overlay(Image(systemName: "camera.fill").font(.caption).foregroundColor(.black))
                                            .offset(x: 35, y: 35)
                                    }
                                }
                                .disabled(isUploading)
                                .onChange(of: selectedItem) { _, _ in uploadAvatar() }
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
                            
                            // Performance Graph
                            StatsGraphView(points: statPoints)
                                .padding(.horizontal)
                            
                            // Actions section
                            VStack(spacing: AppTheme.Spacing.m) {
                                NavigationLink(destination: MyBetsView()) {
                                    ProfileButton(label: "My Bets", icon: "ticket.fill")
                                }
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
            }
            .navigationTitle("Profile")
            .onAppear(perform: fetchProfileStats)
        }
    }
    
    func fetchProfileStats() {
        Task {
            do {
                struct ProfileResponse: Decodable {
                    struct Stats: Decodable {
                        let followersCount: Int
                        let followingCount: Int
                        let walletBalance: Double
                    }
                    let stats: Stats
                }
                
                let res: ProfileResponse = try await APIClient.shared.request("users/profile.php")
                
                DispatchQueue.main.async {
                    self.followersCount = res.stats.followersCount
                    self.followingCount = res.stats.followingCount
                    self.walletBalance = res.stats.walletBalance
                }
                
                // Fetch Graph Data
                let graphData: [StatPoint] = try await APIClient.shared.request("users/stats.php")
                DispatchQueue.main.async {
                    self.statPoints = graphData
                    self.isLoading = false
                }
            } catch {
                print("Failed to fetch profile/stats: \(error)")
                DispatchQueue.main.async { self.isLoading = false }
            }
        }
    }
    
    func uploadAvatar() {
        guard let item = selectedItem else { return }
        isUploading = true
        
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    isUploading = false
                    return
                }
                
                struct AvatarRes: Decodable { let avatarUrl: String }
                let res: AvatarRes = try await APIClient.shared.upload(
                    "users/update_avatar.php",
                    fileData: data,
                    fileName: "avatar.jpg",
                    mimeType: "image/jpeg",
                    fieldName: "avatar"
                )
                
                DispatchQueue.main.async {
                    // Update the user object in AuthStore to reflect the new avatar
                    if var user = authStore.currentUser {
                        user.avatarUrl = res.avatarUrl
                        authStore.currentUser = user
                    }
                    isUploading = false
                    selectedItem = nil
                }
            } catch {
                print("Avatar upload failed: \(error)")
                DispatchQueue.main.async {
                    isUploading = false
                    selectedItem = nil
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
