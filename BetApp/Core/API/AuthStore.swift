import Foundation
import SwiftUI

class AuthStore: ObservableObject {
    static let shared = AuthStore()
    
    @Published var token: String? = UserDefaults.standard.string(forKey: "auth_token")
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    
    init() {
        self.isAuthenticated = token != nil
        if isAuthenticated {
            restoreSession()
        }
    }
    
    func restoreSession() {
        Task {
            do {
                struct ProfileResponse: Decodable {
                    struct UserData: Decodable {
                        let id: Int
                        let username: String
                        let displayName: String
                        let role: String
                    }
                    let user: UserData
                }
                let res: ProfileResponse = try await APIClient.shared.request("users/profile.php")
                DispatchQueue.main.async {
                    self.currentUser = User(id: res.user.id, username: res.user.username, displayName: res.user.displayName, role: res.user.role)
                    self.isAuthenticated = true
                }
            } catch {
                print("Session restoration failed: \(error)")
                DispatchQueue.main.async { self.logout() }
            }
        }
    }

    func login(token: String, user: User) {
        self.token = token
        self.currentUser = user
        self.isAuthenticated = true
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    func logout() {
        self.token = nil
        self.currentUser = nil
        self.isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }
}

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let displayName: String
    let role: String
}
