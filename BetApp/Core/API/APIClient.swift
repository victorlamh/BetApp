import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case unauthorized
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid URL constructed"
        case .noData:              return "No data received from server"
        case .decodingError:       return "Failed to decode server response"
        case .serverError(let m):  return m
        case .unauthorized:        return "Unauthorized - please log in again"
        case .networkError:        return "Network error - check your connection"
        }
    }
}

class APIClient {
    static let shared = APIClient()
    private let baseURL = "https://inject.victorlamache.com/api" // Replace with actual URL
    
    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> T {
        // Use URLComponents for safe URL construction
        let fullPath = baseURL + "/" + endpoint
        
        // Try direct URL first (handles cases where endpoint already has query params)
        guard let url = URL(string: fullPath) ?? {
            // Fallback: split on ? and use URLComponents
            let parts = fullPath.components(separatedBy: "?")
            var components = URLComponents(string: parts[0])
            if parts.count > 1 {
                components?.percentEncodedQuery = parts[1]
            }
            return components?.url
        }() else {
            print("DEBUG: Invalid URL - \(fullPath)")
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
            // Try to read actual error message from PHP response body
            if let errorJson = try? decoder.decode(APIResponse<String>.self, from: data),
               let msg = errorJson.message {
                throw APIError.serverError("[\(httpResponse.statusCode)] \(msg)")
            }
            throw APIError.serverError("Server Error: \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
            if apiResponse.status == "success", let result = apiResponse.data {
                return result
            }
            // Throw server error OUTSIDE the decode try block to avoid it being re-caught
            let msg = apiResponse.message ?? "Unknown server error"
            throw APIError.serverError(msg)
        } catch let apiErr as APIError {
            // Re-throw our own errors directly (don't wrap them)
            throw apiErr
        } catch {
            let errorDescription = "\(error)"
            print("Decoding Error: \(errorDescription)")
            if let decodingError = error as? DecodingError {
                throw APIError.serverError("Decoding Fail: \(decodingError)")
            }
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
