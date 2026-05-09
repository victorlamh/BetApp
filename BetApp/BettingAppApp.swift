import SwiftUI

@main
struct BettingAppApp: App {
    @StateObject private var authStore = AuthStore.shared
    
    var body: some Scene {
        WindowGroup {
            if authStore.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

struct MainTabView: View {
    @ObservedObject var authStore = AuthStore.shared
    
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            UserSearchView()
                .tabItem {
                    Label("Explore", systemImage: "magnifyingglass")
                }
            
            if authStore.currentUser?.role == "admin" {
                AdminView()
                    .tabItem {
                        Label("Admin", systemImage: "shield.fill")
                    }
            }
            
            NotificationsView()
                .tabItem {
                    Label("Activity", systemImage: "bell.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .accentColor(AppTheme.primary)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppTheme.background)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
