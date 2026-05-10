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
                    List {
                        ForEach(notifications.filter { !$0.isRead || $0.type != "follow_request" }) { notification in
                            NotificationRow(notification: notification, onAction: fetchNotifications, onRemoveLocal: {
                                withAnimation {
                                    notifications.removeAll { $0.id == notification.id }
                                }
                            })
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        fetchNotifications()
                    }
                }
            }
            .navigationTitle("Activity")
            .onAppear(perform: fetchNotifications)
        }
    }
    
    func fetchNotifications() {
        if notifications.isEmpty { isLoading = true }
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
    let onAction: () -> Void
    let onRemoveLocal: () -> Void
    @State private var isProcessing = false
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            
            if notification.type == "follow_request", let requesterId = notification.relatedId {
                HStack(spacing: 12) {
                    if isProcessing {
                        ProgressView().tint(AppTheme.primary)
                    } else {
                        Button(action: { handleRequest(accept: true, requesterId: requesterId) }) {
                            Text("Accept")
                                .font(.caption).bold()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AppTheme.primary)
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Button(action: { handleRequest(accept: false, requesterId: requesterId) }) {
                            Text("Refuse")
                                .font(.caption).bold()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AppTheme.cardBackground)
                                .foregroundColor(AppTheme.textPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppTheme.textSecondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(.leading, 42)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.m)
        .alert("Request Failed", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func handleRequest(accept: Bool, requesterId: Int) {
        isProcessing = true
        
        // Optimistic UI update
        onRemoveLocal()
        
        Task {
            do {
                struct EmptyResponse: Decodable {}
                let _: EmptyResponse = try await APIClient.shared.request(
                    "users/follow.php",
                    method: "POST",
                    body: [
                        "action": accept ? "accept" : "refuse",
                        "user_id": requesterId
                    ]
                )
                
                DispatchQueue.main.async {
                    isProcessing = false
                    onAction() // Refresh list from server to sync
                }
            } catch {
                print("Failed to handle follow request: \(error)")
                DispatchQueue.main.async {
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                    self.isProcessing = false
                    onAction() // Refresh anyway
                }
            }
        }
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
