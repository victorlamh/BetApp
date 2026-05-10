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
        let fullPath = baseURL + "/" + endpoint
        guard let url = URL(string: fullPath) else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthStore.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        return try await perform(request)
    }
    
    func upload<T: Decodable>(
        _ endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "file"
    ) async throws -> T {
        let fullPath = baseURL + "/" + endpoint
        guard let url = URL(string: fullPath) else { throw APIError.invalidURL }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return try await perform(request)
    }
    
    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
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
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorJson = try? decoder.decode(APIResponse<String>.self, from: data),
               let msg = errorJson.message {
                throw APIError.serverError("[\(httpResponse.statusCode)] \(msg)")
            }
            throw APIError.serverError("Server Error: \(httpResponse.statusCode)")
        }
        
        do {
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
            if apiResponse.status == "success" {
                if let result = apiResponse.data {
                    return result
                }
                // If T is optional, we could return nil, but for now let's try to decode from empty object if possible
                // or if T is a dummy type, just return a "fake" instance if we can.
                // But a safer way is to just throw if T is required and data is nil.
                // However, many of our endpoints return "success" with no data.
                
                // Let's check if T can be initialized from an empty dict
                if let emptyData = "{}".data(using: .utf8), let result = try? decoder.decode(T.self, from: emptyData) {
                    return result
                }
            }
            let msg = apiResponse.message ?? "Unknown server error"
            throw APIError.serverError(msg)
        } catch let apiErr as APIError {
            throw apiErr
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
