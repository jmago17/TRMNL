import Foundation

actor CloudflareUploadService {
    func upload(imageData: Data, filename: String) async throws -> String {
        let settings = AppSettings.shared

        guard !settings.workerURL.isEmpty, !settings.authSecret.isEmpty else {
            throw UploadError.notConfigured
        }

        let baseURL = settings.workerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/\(filename)") else {
            throw UploadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(settings.authSecret)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw UploadError.serverError(httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(UploadResponse.self, from: data)
        return result.url
    }
}

private struct UploadResponse: Decodable {
    let url: String
}

enum UploadError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Worker URL and auth secret must be set in Settings."
        case .invalidURL: return "Invalid worker URL."
        case .invalidResponse: return "Unexpected response from server."
        case .serverError(let code): return "Server error (\(code))."
        }
    }
}
