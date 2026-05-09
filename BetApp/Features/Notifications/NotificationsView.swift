import SwiftUI

struct NotificationsView: View {
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView().tint(AppTheme.primary)
                } else if notifications.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("No activity yet")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                } else {
                    List(notifications) { notification in
                        NotificationRow(notification: notification)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Activity")
            .onAppear(perform: fetchNotifications)
        }
    }
    
    func fetchNotifications() {
        isLoading = true
        Task {
            do {
                let list: [AppNotification] = try await APIClient.shared.request("notifications/list.php")
                DispatchQueue.main.async {
                    self.notifications = list
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async { self.isLoading = false }
            }
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType(notification.type))
                .foregroundColor(AppTheme.primary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)
                Text(notification.createdAt)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            if !notification.isRead {
                Circle()
                    .fill(AppTheme.primary)
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.m)
    }
    
    func iconForType(_ type: String) -> String {
        switch type {
        case "follow_request": return "person.badge.plus"
        case "follow_accepted": return "person.fill.checkmark"
        case "bet_approved": return "checkmark.seal.fill"
        case "bet_pending": return "shield.fill"
        case "balance_update": return "eurosign.circle.fill"
        default: return "bell.fill"
        }
    }
}

struct AppNotification: Codable, Identifiable {
    let id: Int
    let type: String
    let message: String
    let relatedId: Int?
    let isRead: Bool
    let createdAt: String
}
