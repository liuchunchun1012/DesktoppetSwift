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
            print("[NotionClient] Test failed: No API token")
            completion(false)
            return
        }
        
        let databaseId = UserSettings.shared.notionDatabaseId
        guard !databaseId.isEmpty else {
            print("[NotionClient] Test failed: No database ID")
            completion(false)
            return
        }
        
        // 清理 Database ID（移除可能的 URL 前缀或多余字符）
        let cleanedDbId = cleanDatabaseId(databaseId)
        print("[NotionClient] Testing connection with DB ID: \(cleanedDbId)")
        
        // 尝试获取数据库信息来验证连接
        guard let url = URL(string: "\(baseURL)/databases/\(cleanedDbId)") else {
            print("[NotionClient] Test failed: Invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        
        print("[NotionClient] Sending test request to: \(url)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[NotionClient] Network error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
                print("[NotionClient] Response: \(httpResponse.statusCode) - \(responseBody.prefix(200))")
                
                DispatchQueue.main.async {
                    completion(httpResponse.statusCode == 200)
                }
            } else {
                print("[NotionClient] No HTTP response")
                DispatchQueue.main.async { completion(false) }
            }
        }.resume()
    }
    
    /// 清理 Database ID（从 URL 或带连字符的格式中提取）
    private func cleanDatabaseId(_ input: String) -> String {
        var result = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果是 Notion URL，提取 ID 部分
        if result.contains("notion.so") {
            // https://www.notion.so/workspace/Title-abc123def456...
            // 或 https://notion.so/abc123def456...
            if let range = result.range(of: #"[a-f0-9]{32}"#, options: .regularExpression) {
                result = String(result[range])
            } else if let lastComponent = result.split(separator: "/").last {
                // 尝试获取最后一段
                let idPart = String(lastComponent)
                if let questionMark = idPart.firstIndex(of: "?") {
                    result = String(idPart[..<questionMark])
                } else {
                    result = idPart
                }
                // 如果包含标题，取最后的 32 字符
                if result.count > 32 {
                    result = String(result.suffix(32))
                }
            }
        }
        
        // 移除连字符（有些人复制的 ID 带连字符）
        result = result.replacingOccurrences(of: "-", with: "")
        
        return result
    }
    
    private func buildPageBody(databaseId: String, summary: DailySummary) -> [String: Any] {
        // 清理 Database ID
        let cleanedDbId = cleanDatabaseId(databaseId)
        
        // 映射 mood 到中文
        let moodMap = [
            "Happy": "开心",
            "Neutral": "平静",
            "Frustrated": "沮丧",
            "Excited": "兴奋"
        ]
        let chineseMood = moodMap[summary.mood] ?? "平静"
        
        // 构建标签数组
        var tagsArray: [[String: Any]] = []
        for tag in summary.highlights {
            tagsArray.append(["name": tag])
        }
        
        var properties: [String: Any] = [
            "标题": [
                "title": [
                    ["text": ["content": summary.title]]
                ]
            ],
            "内容": [
                "rich_text": [
                    ["text": ["content": summary.content]]
                ]
            ],
            "情绪": [
                "select": ["name": chineseMood]
            ],
            "日期": [
                "date": ["start": ISO8601DateFormatter().string(from: summary.date)]
            ]
        ]
        
        // 如果有标签，添加标签字段
        if !tagsArray.isEmpty {
            properties["标签"] = ["multi_select": tagsArray]
        }
        
        return [
            "parent": [
                "database_id": cleanedDbId
            ],
            "properties": properties
        ]
    }
    
    // MARK: - Database Query Methods
    
    /// 查询今日日志（用于合并）
    func queryTodayLog(completion: @escaping (Result<ExistingLogPage?, Error>) -> Void) {
        guard let apiKey = KeychainHelper.shared.getNotionToken(), !apiKey.isEmpty else {
            completion(.failure(NotionError.notConfigured))
            return
        }
        
        let databaseId = UserSettings.shared.notionDatabaseId
        guard !databaseId.isEmpty else {
            completion(.failure(NotionError.noDatabaseId))
            return
        }
        
        let cleanedDbId = cleanDatabaseId(databaseId)
        guard let url = URL(string: "\(baseURL)/databases/\(cleanedDbId)/query") else {
            completion(.failure(NotionError.invalidURL))
            return
        }
        
        // 获取今天的日期范围
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let todayString = formatter.string(from: today)
        let tomorrowString = formatter.string(from: tomorrow)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 查询今天的日志（使用日期范围：today <= date < tomorrow）
        let filter: [String: Any] = [
            "filter": [
                "and": [
                    [
                        "property": "日期",
                        "date": ["on_or_after": todayString]
                    ],
                    [
                        "property": "日期",
                        "date": ["before": tomorrowString]
                    ]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: filter)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("[NotionClient] Querying today's log for date: \(todayString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(.success(nil)) }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let firstResult = results.first {
                    
                    let pageId = firstResult["id"] as? String ?? ""
                    var existingContent = ""
                    
                    // 提取现有内容
                    if let properties = firstResult["properties"] as? [String: Any],
                       let contentProp = properties["内容"] as? [String: Any],
                       let richText = contentProp["rich_text"] as? [[String: Any]],
                       let firstText = richText.first,
                       let textObj = firstText["text"] as? [String: Any],
                       let content = textObj["content"] as? String {
                        existingContent = content
                    }
                    
                    print("[NotionClient] Found existing log: \(pageId)")
                    let page = ExistingLogPage(id: pageId, content: existingContent)
                    DispatchQueue.main.async { completion(.success(page)) }
                } else {
                    print("[NotionClient] No existing log found for today")
                    DispatchQueue.main.async { completion(.success(nil)) }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
    
    /// 更新现有日志页面（追加内容）
    func updatePageContent(pageId: String, newContent: String, newTags: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let apiKey = KeychainHelper.shared.getNotionToken(), !apiKey.isEmpty else {
            completion(.failure(NotionError.notConfigured))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/pages/\(pageId)") else {
            completion(.failure(NotionError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建标签数组
        var tagsArray: [[String: Any]] = []
        for tag in newTags {
            tagsArray.append(["name": tag])
        }
        
        var properties: [String: Any] = [
            "内容": [
                "rich_text": [
                    ["text": ["content": newContent]]
                ]
            ]
        ]
        
        if !tagsArray.isEmpty {
            properties["标签"] = ["multi_select": tagsArray]
        }
        
        let body: [String: Any] = ["properties": properties]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("[NotionClient] Updating page: \(pageId)")
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    print("[NotionClient] Page updated successfully!")
                    DispatchQueue.main.async { completion(.success(())) }
                } else {
                    let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                    print("[NotionClient] Update error: \(httpResponse.statusCode) - \(errorMessage)")
                    DispatchQueue.main.async {
                        completion(.failure(NotionError.apiError(httpResponse.statusCode, errorMessage)))
                    }
                }
            }
        }.resume()
    }
    
    /// 查询今日 TodoList 任务
    func queryTodayTasks(completion: @escaping (Result<[TaskSummaryItem], Error>) -> Void) {
        guard let apiKey = KeychainHelper.shared.getNotionToken(), !apiKey.isEmpty else {
            completion(.success([]))  // 没有配置时返回空数组
            return
        }
        
        let databaseId = UserSettings.shared.todoListDatabaseId
        guard !databaseId.isEmpty else {
            completion(.success([]))  // 没有配置 TodoList 时返回空数组
            return
        }
        
        let cleanedDbId = cleanDatabaseId(databaseId)
        guard let url = URL(string: "\(baseURL)/databases/\(cleanedDbId)/query") else {
            completion(.failure(NotionError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 查询所有任务（不过滤日期，获取全部任务状态）
        // 可以在这里加过滤条件，比如只查询未完成的任务
        let filter: [String: Any] = [:]  // 空 filter = 获取所有任务
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: filter)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("[NotionClient] Querying today's tasks")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(.success([])) }
                return
            }
            
            do {
                var tasks: [TaskSummaryItem] = []
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]] {
                    
                    for result in results {
                        if let properties = result["properties"] as? [String: Any] {
                            // 提取任务名称
                            var name = "未命名任务"
                            if let titleProp = properties["任务名称"] as? [String: Any],
                               let titleArr = titleProp["title"] as? [[String: Any]],
                               let firstTitle = titleArr.first,
                               let textObj = firstTitle["text"] as? [String: Any],
                               let content = textObj["content"] as? String {
                                name = content
                            }
                            
                            // 提取状态
                            var status = "未开始"
                            if let statusProp = properties["状态"] as? [String: Any],
                               let statusObj = statusProp["status"] as? [String: Any],
                               let statusName = statusObj["name"] as? String {
                                status = statusName
                            }
                            
                            tasks.append(TaskSummaryItem(name: name, status: status))
                        }
                    }
                }
                
                print("[NotionClient] Found \(tasks.count) tasks for today")
                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}

/// 现有日志页面
struct ExistingLogPage {
    let id: String
    let content: String
}

/// 任务摘要项（用于日志整合）
struct TaskSummaryItem {
    let name: String
    let status: String  // 未开始 / 进行中 / 已完成
}

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

/// TodoList 任务数据结构
struct TodoTask {
    let name: String           // 任务名称
    let priority: String       // 高/中/低
    let startDate: Date?       // 开始时间
    let dueDate: Date?         // 截止时间
    let tags: [String]         // 标签：想法/工作/学习/项目/生活/紧急
    let status: String         // 未开始/进行中/已完成
    let type: String           // 临时任务/番茄钟/每日任务/长期任务
    
    init(name: String, priority: String = "中", startDate: Date? = nil, dueDate: Date? = nil, tags: [String] = [], status: String = "未开始", type: String = "临时任务") {
        self.name = name
        self.priority = priority
        self.startDate = startDate
        self.dueDate = dueDate
        self.tags = tags
        self.status = status
        self.type = type
    }
}

// MARK: - NotionClient Extension for TodoList

extension NotionClient {
    
    /// 创建 TodoList 任务
    func createTask(_ task: TodoTask, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let apiKey = KeychainHelper.shared.getNotionToken(), !apiKey.isEmpty else {
            completion(.failure(NotionError.notConfigured))
            return
        }
        
        let databaseId = UserSettings.shared.todoListDatabaseId
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
        
        let body = buildTaskBody(databaseId: databaseId, task: task)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("[NotionClient] Creating task: \(task.name)")
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    print("[NotionClient] Task created successfully!")
                    DispatchQueue.main.async { completion(.success(())) }
                } else {
                    let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                    print("[NotionClient] Task creation error: \(httpResponse.statusCode) - \(errorMessage)")
                    DispatchQueue.main.async {
                        completion(.failure(NotionError.apiError(httpResponse.statusCode, errorMessage)))
                    }
                }
            }
        }.resume()
    }
    
    /// 构建 TodoList 任务请求体
    private func buildTaskBody(databaseId: String, task: TodoTask) -> [String: Any] {
        let cleanedDbId = cleanDatabaseId(databaseId)
        
        // 构建标签数组
        var tagsArray: [[String: Any]] = []
        for tag in task.tags {
            tagsArray.append(["name": tag])
        }
        
        var properties: [String: Any] = [
            "任务名称": [
                "title": [
                    ["text": ["content": task.name]]
                ]
            ],
            "优先级": [
                "select": ["name": task.priority]
            ],
            "状态": [
                "status": ["name": task.status]
            ],
            "类型": [
                "select": ["name": task.type]
            ]
        ]
        
        // 可选字段：开始时间
        if let startDate = task.startDate {
            properties["开始时间"] = [
                "date": ["start": ISO8601DateFormatter().string(from: startDate)]
            ]
        }
        
        // 可选字段：截止日期
        if let dueDate = task.dueDate {
            properties["截止时间"] = [
                "date": ["start": ISO8601DateFormatter().string(from: dueDate)]
            ]
        }
        
        // 可选字段：标签
        if !tagsArray.isEmpty {
            properties["标签"] = ["multi_select": tagsArray]
        }
        
        return [
            "parent": ["database_id": cleanedDbId],
            "properties": properties
        ]
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

