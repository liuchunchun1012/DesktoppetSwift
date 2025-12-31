import Foundation

/// 任务解析器
/// 检测 "记任务：" 前缀并调用 AI 提取任务信息
class TaskParser {
    static let shared = TaskParser()
    
    private init() {}
    
    /// 检查消息是否是任务命令
    static func isTaskCommand(_ message: String) -> Bool {
        let prefixes = ["记任务：", "记任务:", "记任务 ", "添加任务：", "添加任务:"]
        return prefixes.contains { message.hasPrefix($0) }
    }
    
    /// 提取任务内容（去掉前缀）
    static func extractTaskContent(_ message: String) -> String {
        let prefixes = ["记任务：", "记任务:", "记任务 ", "添加任务：", "添加任务:"]
        for prefix in prefixes {
            if message.hasPrefix(prefix) {
                return String(message.dropFirst(prefix.count))
            }
        }
        return message
    }
    
    /// 解析任务并创建到 Notion
    func parseAndCreate(_ content: String, completion: @escaping (Result<TodoTask, Error>) -> Void) {
        // 构建 AI prompt
        let prompt = buildExtractionPrompt(content)
        
        // 调用 AI 提取结构化信息
        AIProviderManager.shared.chatStream(
            message: prompt,
            onUpdate: { _ in },  // 不需要流式更新
            onComplete: { [weak self] result in
                switch result {
                case .success(let response):
                    if let task = self?.parseAIResponse(response, originalContent: content) {
                        // 发送到 Notion
                        NotionClient.shared.createTask(task) { notionResult in
                            switch notionResult {
                            case .success:
                                completion(.success(task))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    } else {
                        // 解析失败，使用原始内容创建简单任务
                        let simpleTask = TodoTask(name: content)
                        NotionClient.shared.createTask(simpleTask) { notionResult in
                            switch notionResult {
                            case .success:
                                completion(.success(simpleTask))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
    
    // MARK: - Private Methods
    
    private func buildExtractionPrompt(_ content: String) -> String {
        return """
你是一个任务解析助手。请从用户消息中提取任务信息，返回 JSON 格式。
注意：直接返回 JSON，不要用 markdown 代码块包裹。

可用选项：
- priority（优先级）：高、中、低
- tags（标签）：想法、工作、学习、项目、生活、紧急（可多选）
- type（类型）：临时任务、番茄钟、每日任务、长期任务
- status（状态）：未开始、进行中、已完成（根据用户描述判断，默认未开始）
- dueDate（截止日期）：ISO8601 格式，如 2025-01-01，可选

返回格式：
{"name": "任务名称", "priority": "中", "tags": ["工作"], "type": "临时任务", "status": "未开始", "dueDate": null}

用户消息：\(content)
"""
    }
    
    private func parseAIResponse(_ response: String, originalContent: String) -> TodoTask? {
        // 尝试提取 JSON
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}") else {
            print("[TaskParser] No JSON found in response")
            return nil
        }
        
        let jsonString = String(response[jsonStart...jsonEnd])
        
        guard let data = jsonString.data(using: .utf8) else {
            print("[TaskParser] Failed to convert to data")
            return nil
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            let name = json?["name"] as? String ?? originalContent
            let priority = json?["priority"] as? String ?? "中"
            let tags = json?["tags"] as? [String] ?? []
            let type = json?["type"] as? String ?? "临时任务"
            let status = json?["status"] as? String ?? "未开始"
            
            var dueDate: Date? = nil
            if let dueDateString = json?["dueDate"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]
                dueDate = formatter.date(from: dueDateString)
            }
            
            return TodoTask(
                name: name,
                priority: priority,
                dueDate: dueDate,
                tags: tags,
                status: status,
                type: type
            )
        } catch {
            print("[TaskParser] JSON parse error: \(error)")
            return nil
        }
    }
}

// MARK: - Errors

enum TaskParserError: Error, LocalizedError {
    case noTodoListDatabase
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .noTodoListDatabase:
            return "未设置 TodoList Database ID，请在设置中配置"
        case .parseError:
            return "无法解析任务信息"
        }
    }
}
