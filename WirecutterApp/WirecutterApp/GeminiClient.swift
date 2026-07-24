import Foundation

final class GeminiClient {
    static let shared = GeminiClient()

    private var apiKey: String {
        // Reads from GeminiConfig.plist (gitignored) or falls back to empty
        guard let path = Bundle.main.path(forResource: "GeminiConfig", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["API_KEY"] as? String, !key.isEmpty else {
            return ""
        }
        return key
    }

    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    private let systemPrompt = """
    You are "Wirecutter Finder," an AI shopping assistant powered by NYT Wirecutter's expert product reviews. \
    Answer concisely in 2-3 paragraphs. Recommend specific products when possible, \
    mention price ranges, and explain WHY each pick is good based on testing. \
    If you're unsure, say so and suggest the user check wirecutter.com for the full review. \
    Keep responses helpful, warm, and authoritative.
    """

    func ask(query: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiError.noApiKey
        }

        guard var components = URLComponents(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                [
                    "parts": [["text": query]]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 1024
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        return try parseResponse(data)
    }

    private func parseResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiError.parsingFailed
        }
        return text
    }
}

enum GeminiError: LocalizedError {
    case noApiKey
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "Gemini API key not configured. Add it to GeminiConfig.plist."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .parsingFailed:
            return "Failed to parse Gemini response"
        }
    }
}
