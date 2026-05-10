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
            
            MyBetsView()
                .tabItem {
                    Label("My Bets", systemImage: "ticket.fill")
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
