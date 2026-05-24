import Foundation

struct SearXNGSearchResult: Codable {
    let title: String
    let url: String
    let content: String
}

private struct SearXNGResponse: Decodable {
    let results: [SearXNGResult]
}

private struct SearXNGResult: Decodable {
    let title: String?
    let url: String?
    let content: String?
}

enum SearXNGError: Error, LocalizedError {
    case noUsableInstance
    
    var errorDescription: String? {
        switch self {
        case .noUsableInstance:
            return "No available SearXNG instance returned JSON search results."
        }
    }
}

final class SearXNGClient {
    static let shared = SearXNGClient()
    
    private let publicInstances = [
        "https://searx.be",
        "https://search.sapti.me",
        "https://searx.tiekoetter.com",
        "https://searxng.world"
    ]
    
    private init() {}
    
    func search(query: String, count: Int, completion: @escaping (Result<[SearXNGSearchResult], Error>) -> Void) {
        let customBaseURL = UserSettings.shared.searxngBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let bases = ([customBaseURL].filter { !$0.isEmpty } + publicInstances)
        search(query: query, count: count, bases: bases, index: 0, completion: completion)
    }
    
    private func search(
        query: String,
        count: Int,
        bases: [String],
        index: Int,
        completion: @escaping (Result<[SearXNGSearchResult], Error>) -> Void
    ) {
        guard index < bases.count else {
            completion(.failure(SearXNGError.noUsableInstance))
            return
        }
        
        guard let url = makeSearchURL(base: bases[index], query: query) else {
            search(query: query, count: count, bases: bases, index: index + 1, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Meowpal/DeepSeekWebSearch", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[SearXNG] Instance failed: \(bases[index]) \(error.localizedDescription)")
                self.search(query: query, count: count, bases: bases, index: index + 1, completion: completion)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data,
                  let decoded = try? JSONDecoder().decode(SearXNGResponse.self, from: data) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[SearXNG] Instance returned unusable response: \(bases[index]) status=\(status)")
                self.search(query: query, count: count, bases: bases, index: index + 1, completion: completion)
                return
            }
            
            let limit = max(1, min(count, 10))
            let results = decoded.results.compactMap { result -> SearXNGSearchResult? in
                guard let title = result.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let url = result.url?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !title.isEmpty,
                      !url.isEmpty else {
                    return nil
                }
                
                let content = result.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return SearXNGSearchResult(title: title, url: url, content: content)
            }
            .prefix(limit)
            
            completion(.success(Array(results)))
        }.resume()
    }
    
    private func makeSearchURL(base: String, query: String) -> URL? {
        let trimmed = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: "\(trimmed)/search") else {
            return nil
        }
        
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "language", value: "auto"),
            URLQueryItem(name: "safesearch", value: "1")
        ]
        return components.url
    }
    
    static func formatToolResult(query: String, results: [SearXNGSearchResult]) -> String {
        guard !results.isEmpty else {
            return "No web results found for query: \(query)"
        }
        
        var lines = ["Web search results for: \(query)"]
        for (index, result) in results.enumerated() {
            lines.append("""
            
            [\(index + 1)] \(result.title)
            URL: \(result.url)
            Snippet: \(result.content.isEmpty ? "No snippet available." : result.content)
            """)
        }
        return lines.joined(separator: "\n")
    }
}
