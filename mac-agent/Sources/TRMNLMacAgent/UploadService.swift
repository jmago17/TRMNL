import Foundation

actor UploadService {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func upload(imageData: Data, filename: String) async throws -> String {
        guard !config.workerURL.isEmpty else {
            throw AgentError.notConfigured("workerURL")
        }
        guard !config.authSecret.isEmpty else {
            throw AgentError.notConfigured("authSecret")
        }

        let baseURL = config.workerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let rawURL = "\(baseURL)/\(filename)"
        guard let url = URL(string: rawURL) else {
            throw AgentError.invalidURL(rawURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(config.authSecret)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw AgentError.serverError("Cloudflare worker", httpResponse.statusCode)
        }

        return try JSONDecoder().decode(UploadResponse.self, from: data).url
    }
}

private struct UploadResponse: Decodable {
    let url: String
}
