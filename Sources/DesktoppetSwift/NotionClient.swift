import Foundation

/// Notion API 客户端
/// 负责将每日总结发送到 Notion Database
class NotionClient {
    static let shared = NotionClient()
    
    private let baseURL = "https://api.notion.com/v1"
    private let notionVersion = "2022-06-28"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 发送每日总结到 Notion
    func postDailySummary(_ summary: DailySummary, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let apiKey = KeychainHelper.shared.getNotionToken(), !apiKey.isEmpty else {
            completion(.failure(NotionError.notConfigured))
            return
        }
        
        let databaseId = UserSettings.shared.notionDatabaseId
        guard !databaseId.isEmpty else {
            completion(.failure(NotionError.noDatabaseId))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/pages") else {
            completion(.failure(NotionError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建 Notion Page 请求体
        let body = buildPageBody(databaseId: databaseId, summary: summary)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    print("[NotionClient] Successfully posted to Notion")
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                } else {
                    let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                    print("[NotionClient] Error: \(httpResponse.statusCode) - \(errorMessage)")
                    DispatchQueue.main.async {
                        completion(.failure(NotionError.apiError(httpResponse.statusCode, errorMessage)))
                    }
                }
            }
        }.resume()
    }
    
    /// 测试 Notion 连接
    func testConnection(completion: @escaping (Bool) -> Void) {
        guard let apiKey = KeychainHelper.shared.getNotionToken(), !apiKey.isEmpty else {
            completion(false)
            return
        }
        
        let databaseId = UserSettings.shared.notionDatabaseId
        guard !databaseId.isEmpty else {
            completion(false)
            return
        }
        
        // 尝试获取数据库信息来验证连接
        guard let url = URL(string: "\(baseURL)/databases/\(databaseId)") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                DispatchQueue.main.async {
                    completion(httpResponse.statusCode == 200)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Private Methods
    
    private func buildPageBody(databaseId: String, summary: DailySummary) -> [String: Any] {
        // ISO 8601 日期格式
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dateString = dateFormatter.string(from: summary.date)
        
        return [
            "parent": [
                "database_id": databaseId
            ],
            "properties": [
                "Name": [
                    "title": [
                        ["text": ["content": summary.title]]
                    ]
                ],
                "Content": [
                    "rich_text": [
                        ["text": ["content": summary.content]]
                    ]
                ],
                "Category": [
                    "select": ["name": summary.category]
                ],
                "Mood": [
                    "select": ["name": summary.mood]
                ],
                "Date": [
                    "date": ["start": dateString]
                ],
                "Status": [
                    "status": ["name": "New"]
                ]
            ]
        ]
    }
}

// MARK: - Data Models

/// 每日总结数据结构
struct DailySummary: Codable {
    let title: String       // 一句话标题
    let content: String     // 总结正文
    let category: String    // Dev / Life / Idea / Random
    let mood: String        // Happy / Neutral / Frustrated / Excited
    let highlights: [String]  // 关键成就
    let date: Date
    
    init(title: String, content: String, category: String = "Random", mood: String = "Neutral", highlights: [String] = [], date: Date = Date()) {
        self.title = title
        self.content = content
        self.category = category
        self.mood = mood
        self.highlights = highlights
        self.date = date
    }
}

// MARK: - Errors

enum NotionError: Error, LocalizedError {
    case notConfigured
    case noDatabaseId
    case invalidURL
    case apiError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Notion 未配置，请在设置中填入 Integration Token"
        case .noDatabaseId:
            return "未设置 Notion Database ID"
        case .invalidURL:
            return "无效的 URL"
        case .apiError(let code, let message):
            return "Notion API 错误 (\(code)): \(message)"
        }
    }
}
