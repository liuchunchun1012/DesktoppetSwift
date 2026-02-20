import Foundation

/// 任务解析器
/// 检测 "Add task: " 前缀并调用 AI 提取任务信息
class TaskParser {
    static let shared = TaskParser()
    
    private init() {}
    
    /// 检查消息是否是任务命令（以 + 开头）
    static func isTaskCommand(_ message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("+")
    }

    /// 提取任务内容（去掉 + 前缀）
    static func extractTaskContent(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("+") {
            let content = String(trimmed.dropFirst())
            return content.trimmingCharacters(in: .whitespaces)
        }
        return message
    }
    
    /// 仅解析任务（不保存，返回解析后的任务列表）
    func parseOnly(_ content: String, completion: @escaping (Result<[TodoTask], Error>) -> Void) {
        let prompt = buildExtractionPrompt(content)

        AIProviderManager.shared.chatStream(
            message: prompt,
            onUpdate: { _ in },
            onComplete: { [weak self] result in
                switch result {
                case .success(let response):
                    let tasks = self?.parseAIResponseMultiple(response, originalContent: content) ?? []

                    if tasks.isEmpty {
                        // 解析失败，使用原始内容创建一个简单任务
                        let simpleTask = TodoTask(name: content)
                        completion(.success([simpleTask]))
                    } else {
                        completion(.success(tasks))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }

    /// 解析任务并创建到 Notion（支持一次创建多个任务）
    /// 注意：此方法仅保存到 Notion，如需同时保存到 Obsidian，请使用 parseOnly 后自行处理
    func parseAndCreate(_ content: String, completion: @escaping (Result<[TodoTask], Error>) -> Void) {
        parseOnly(content) { [weak self] result in
            switch result {
            case .success(let tasks):
                self?.createTasksSequentially(tasks, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 顺序创建多个任务
    private func createTasksSequentially(_ tasks: [TodoTask], completion: @escaping (Result<[TodoTask], Error>) -> Void) {
        var createdTasks: [TodoTask] = []
        var remainingTasks = tasks
        
        func createNext() {
            guard !remainingTasks.isEmpty else {
                completion(.success(createdTasks))
                return
            }
            
            let task = remainingTasks.removeFirst()
            NotionClient.shared.createTask(task) { result in
                switch result {
                case .success:
                    createdTasks.append(task)
                    createNext()
                case .failure(let error):
                    // 即使某个失败，也继续创建其他的
                    print("[TaskParser] Failed to create task: \(task.name), error: \(error)")
                    createNext()
                }
            }
        }
        
        createNext()
    }
    
    // MARK: - Private Methods
    
    private func buildExtractionPrompt(_ content: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        formatter.dateFormat = "HH:mm"
        let now = formatter.string(from: Date())
        
        return """
你是一个任务解析助手。请从用户消息中提取所有任务，返回 JSON 数组。
今天是 \(today)，当前时间是 \(now)。

时间解析规则：
- 如果用户说 "10:40-12:40"，startTime=10:40，dueTime=12:40
- 如果用户说 "明天"，startDate=明天日期
- 如果用户没说日期，默认今天
- 如果用户没说时间，默认当前时间

可用选项：
- priority：高、中、低
- tags：想法、工作、学习、项目、生活、紧急
- type：临时任务、番茄钟、每日任务、长期任务
- status：未开始、进行中、已完成
- startDateTime：开始时间（YYYY-MM-DDTHH:mm，如 \(today)T\(now)）
- dueDateTime：截止时间（YYYY-MM-DDTHH:mm，可选）

返回格式：
[{"name":"任务","priority":"中","tags":["工作"],"type":"临时任务","status":"未开始","startDateTime":"\(today)T\(now)","dueDateTime":null}]

用户消息：\(content)
"""
    }
    
    /// 解析多个任务
    private func parseAIResponseMultiple(_ response: String, originalContent: String) -> [TodoTask] {
        // 尝试找到 JSON 数组
        guard let jsonStart = response.firstIndex(of: "["),
              let jsonEnd = response.lastIndex(of: "]") else {
            // 尝试单个对象格式
            if let task = parseAIResponseSingle(response, originalContent: originalContent) {
                return [task]
            }
            print("[TaskParser] No JSON array found in response")
            return []
        }
        
        let jsonString = String(response[jsonStart...jsonEnd])
        
        guard let data = jsonString.data(using: .utf8) else {
            print("[TaskParser] Failed to convert to data")
            return []
        }
        
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            
            return jsonArray.compactMap { json -> TodoTask? in
                guard let name = json["name"] as? String, !name.isEmpty else { return nil }
                
                let priority = json["priority"] as? String ?? "中"
                let tags = json["tags"] as? [String] ?? []
                let type = json["type"] as? String ?? "临时任务"
                let status = json["status"] as? String ?? "未开始"
                
                // 解析日期时间（格式：YYYY-MM-DDTHH:mm）
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
                formatter.timeZone = TimeZone.current
                
                var startDate: Date? = Date()  // 默认当前时间
                if let startStr = json["startDateTime"] as? String {
                    startDate = formatter.date(from: startStr) ?? Date()
                }
                
                var dueDate: Date? = nil
                if let dueStr = json["dueDateTime"] as? String {
                    dueDate = formatter.date(from: dueStr)
                }
                
                return TodoTask(
                    name: name,
                    priority: priority,
                    startDate: startDate,
                    dueDate: dueDate,
                    tags: tags,
                    status: status,
                    type: type
                )
            }
        } catch {
            print("[TaskParser] JSON parse error: \(error)")
            return []
        }
    }
    
    /// 解析单个任务（兼容旧格式）
    private func parseAIResponseSingle(_ response: String, originalContent: String) -> TodoTask? {
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}") else {
            return nil
        }
        
        let jsonString = String(response[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            return nil
        }
        
        return TodoTask(
            name: name,
            priority: json["priority"] as? String ?? "中",
            startDate: Date(),  // 默认今天
            dueDate: nil,
            tags: json["tags"] as? [String] ?? [],
            status: json["status"] as? String ?? "未开始",
            type: json["type"] as? String ?? "临时任务"
        )
    }
}

// MARK: - Errors

enum TaskParserError: Error, LocalizedError {
    case noTodoListDatabase
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .noTodoListDatabase:
            return "TodoList Database ID not set. Please configure in Settings"
        case .parseError:
            return "无法解析任务信息"
        }
    }
}
