import Foundation

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case unauthorized
    case networkError
}

class APIClient {
    static let shared = APIClient()
    private let baseURL = "https://inject.victorlamache.com/api" // Replace with actual URL
    
    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> T {
        // Handle query parameters if present in endpoint
        let urlString = baseURL + "/" + endpoint
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthStore.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("🌐 Network Error: \(error)")
            throw APIError.networkError
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response from server")
        }
        
        if httpResponse.statusCode == 401 {
            AuthStore.shared.logout()
            throw APIError.unauthorized
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw APIError.serverError("Server Error: \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
            if apiResponse.status == "success", let result = apiResponse.data {
                return result
            } else {
                throw APIError.serverError(apiResponse.message ?? "Unknown error")
            }
        } catch {
            print("Decoding Error: \(error)")
            throw APIError.decodingError
        }
    }
}

// Handle API success/error structure
struct APIResponse<D: Decodable>: Decodable {
    let status: String
    let message: String?
    let data: D?
    let errors: [String: [String]]?
}
