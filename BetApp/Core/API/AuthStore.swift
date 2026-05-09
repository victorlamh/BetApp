import Foundation
import SwiftUI

class AuthStore: ObservableObject {
    static let shared = AuthStore()
    
    @Published var token: String? = UserDefaults.standard.string(forKey: "auth_token")
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    
    init() {
        self.isAuthenticated = token != nil
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
