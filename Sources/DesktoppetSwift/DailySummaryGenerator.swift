import Foundation

/// 每日总结生成器
/// 使用 AI 从当天的对话记录生成结构化总结
class DailySummaryGenerator {
    static let shared = DailySummaryGenerator()
    
    private init() {}
    
    /// 生成今日总结并发送到 Notion
    func generateAndPost(completion: @escaping (Result<DailySummary, Error>) -> Void) {
        let logs = ChatLogManager.shared.getUnsyncedToNotion()
        
        guard !logs.isEmpty else {
            completion(.failure(SummaryError.noConversations))
            return
        }
        
        // 构建 AI 提示词
        let prompt = buildPrompt(from: logs)
        
        // 调用 AI 生成结构化总结
        AIProviderManager.shared.chatStream(
            message: prompt,
            onUpdate: { _ in },  // 不需要流式更新
            onComplete: { [weak self] result in
                switch result {
                case .success(let response):
                    if let summary = self?.parseResponse(response) {
                        // 发送到 Notion
                        NotionClient.shared.postDailySummary(summary) { notionResult in
                            switch notionResult {
                            case .success:
                                // 标记对话已同步
                                ChatLogManager.shared.markSyncedToNotion()
                                completion(.success(summary))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    } else {
                        completion(.failure(SummaryError.parseError))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
    
    /// 仅生成总结（不发送到 Notion）
    func generateSummary(completion: @escaping (Result<DailySummary, Error>) -> Void) {
        let logs = ChatLogManager.shared.getTodayConversations()
        
        guard !logs.isEmpty else {
            completion(.failure(SummaryError.noConversations))
            return
        }
        
        let prompt = buildPrompt(from: logs)
        
        AIProviderManager.shared.chatStream(
            message: prompt,
            onUpdate: { _ in },
            onComplete: { [weak self] result in
                switch result {
                case .success(let response):
                    if let summary = self?.parseResponse(response) {
                        completion(.success(summary))
                    } else {
                        completion(.failure(SummaryError.parseError))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
    
    // MARK: - Private Methods
    
    private func buildPrompt(from logs: [ChatLogEntry]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "yyyy年MM月dd日"
        let dateString = dateFormatter.string(from: Date())
        
        var conversationsText = ""
        for (index, log) in logs.enumerated() {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeString = timeFormatter.string(from: log.timestamp)
            
            conversationsText += """
            【对话 \(index + 1)】(\(timeString))
            用户：\(log.userMessage)
            AI：\(log.aiResponse)
            
            """
        }
        
        return """
        你是一个日记整理助手。请根据今天（\(dateString)）的对话记录，生成一份简短的每日总结。

        今日对话记录：
        \(conversationsText)

        请按以下 JSON 格式输出（只输出 JSON，不要其他文字）：
        {
            "title": "一句话概括今天最重要的事（不超过30字）",
            "content": "2-3句话总结今天的主要内容和心情",
            "category": "Dev 或 Life 或 Idea 或 Random",
            "mood": "Happy 或 Neutral 或 Frustrated 或 Excited",
            "highlights": ["成就1", "成就2"]
        }

        分类说明：
        - Dev：开发、编程、技术相关
        - Life：日常生活、情感、健康
        - Idea：灵感、想法、创意
        - Random：其他随机话题

        情绪说明：
        - Happy：开心、满足
        - Neutral：平静、一般
        - Frustrated：沮丧、烦躁
        - Excited：兴奋、激动
        """
    }
    
    private func parseResponse(_ response: String) -> DailySummary? {
        // 尝试从响应中提取 JSON
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果响应被 ``` 包裹，去掉它们
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = jsonString.data(using: .utf8) else {
            print("[DailySummaryGenerator] Failed to convert response to data")
            return nil
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let title = json?["title"] as? String,
                  let content = json?["content"] as? String else {
                print("[DailySummaryGenerator] Missing required fields in JSON")
                return nil
            }
            
            let category = json?["category"] as? String ?? "Random"
            let mood = json?["mood"] as? String ?? "Neutral"
            let highlights = json?["highlights"] as? [String] ?? []
            
            return DailySummary(
                title: title,
                content: content,
                category: category,
                mood: mood,
                highlights: highlights
            )
        } catch {
            print("[DailySummaryGenerator] JSON parse error: \(error)")
            return nil
        }
    }
}

// MARK: - Errors

enum SummaryError: Error, LocalizedError {
    case noConversations
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .noConversations:
            return "今天还没有对话记录哦！"
        case .parseError:
            return "AI 返回的格式无法解析"
        }
    }
}
