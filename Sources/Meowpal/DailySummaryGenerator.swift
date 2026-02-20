import Foundation

/// 每日总结生成器
/// 使用 AI 从当天的对话记录生成结构化总结
class DailySummaryGenerator {
    static let shared = DailySummaryGenerator()
    
    private init() {}
    
    /// 生成今日总结并发送到配置的目标（Notion / Obsidian / Both）
    func generateAndPost(completion: @escaping (Result<DailySummary, Error>) -> Void) {
        let logs = ChatLogManager.shared.getUnsyncedToNotion()

        guard !logs.isEmpty else {
            completion(.failure(SummaryError.noConversations))
            return
        }

        let destination = UserSettings.shared.summaryDestination
        let notionConfigured = !UserSettings.shared.notionDatabaseId.isEmpty
        let obsidianConfigured = ObsidianClient.shared.isConfigured()

        // Step 1: 查询 TodoList 任务 (仅当需要 Notion 时)
        let queryTasks: (@escaping ([TaskSummaryItem]) -> Void) -> Void = { callback in
            if (destination == .notion || destination == .both) && notionConfigured {
                NotionClient.shared.queryTodayTasks { result in
                    callback((try? result.get()) ?? [])
                }
            } else {
                callback([])
            }
        }

        queryTasks { [weak self] tasks in
            // Step 2: 查询是否已有今日 Notion 日志
            let queryLog: (@escaping (ExistingLogPage?) -> Void) -> Void = { callback in
                if (destination == .notion || destination == .both) && notionConfigured {
                    NotionClient.shared.queryTodayLog { result in
                        callback(try? result.get())
                    }
                } else {
                    callback(nil)
                }
            }

            queryLog { existingLog in
                // Step 3: 构建 AI 提示词
                let prompt = self?.buildPromptWithTasks(from: logs, tasks: tasks, existingContent: existingLog?.content) ?? ""

                // Step 4: 调用 AI 生成总结
                AIProviderManager.shared.chatStream(
                    message: prompt,
                    onUpdate: { _ in },
                    onComplete: { [weak self] result in
                        switch result {
                        case .success(let response):
                            if let summary = self?.parseResponse(response) {
                                // Step 5: 保存到配置的目标
                                self?.saveSummary(summary, destination: destination, notionConfigured: notionConfigured, obsidianConfigured: obsidianConfigured, existingLog: existingLog, completion: completion)
                            } else {
                                completion(.failure(SummaryError.parseError))
                            }
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                )
            }
        }
    }

    /// 保存总结到配置的目标
    private func saveSummary(
        _ summary: DailySummary,
        destination: TaskDestination,
        notionConfigured: Bool,
        obsidianConfigured: Bool,
        existingLog: ExistingLogPage?,
        completion: @escaping (Result<DailySummary, Error>) -> Void
    ) {
        let group = DispatchGroup()
        var errors: [String] = []
        var savedTo: [String] = []

        // 保存到 Notion
        if (destination == .notion || destination == .both) && notionConfigured {
            group.enter()
            if let existingPage = existingLog {
                NotionClient.shared.updatePageContent(
                    pageId: existingPage.id,
                    newContent: summary.content,
                    newTags: summary.highlights
                ) { result in
                    switch result {
                    case .success:
                        savedTo.append("Notion")
                    case .failure(let error):
                        errors.append("Notion: \(error.localizedDescription)")
                    }
                    group.leave()
                }
            } else {
                NotionClient.shared.postDailySummary(summary) { result in
                    switch result {
                    case .success:
                        savedTo.append("Notion")
                    case .failure(let error):
                        errors.append("Notion: \(error.localizedDescription)")
                    }
                    group.leave()
                }
            }
        }

        // 保存到 Obsidian
        if (destination == .obsidian || destination == .both) && obsidianConfigured {
            group.enter()
            ObsidianClient.shared.saveDailySummary(summary) { result in
                switch result {
                case .success:
                    savedTo.append("Obsidian")
                case .failure(let error):
                    errors.append("Obsidian: \(error.localizedDescription)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !savedTo.isEmpty {
                ChatLogManager.shared.markSyncedToNotion()
                print("[DailySummaryGenerator] Saved to: \(savedTo.joined(separator: ", "))")
                completion(.success(summary))
            } else if !errors.isEmpty {
                completion(.failure(SummaryError.saveError(errors.joined(separator: "; "))))
            } else {
                completion(.failure(SummaryError.noDestination))
            }
        }
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
    
    /// 构建包含任务信息的 AI 提示词
    private func buildPromptWithTasks(from logs: [ChatLogEntry], tasks: [TaskSummaryItem], existingContent: String?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "yyyy年MM月dd日"
        let dateString = dateFormatter.string(from: Date())
        
        // 构建对话文本
        var conversationsText = ""
        for (index, log) in logs.enumerated() {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeString = timeFormatter.string(from: log.timestamp)
            
            conversationsText += """
            【对话 \(index + 1)】(\(timeString))
            User: \(log.userMessage)
            AI：\(log.aiResponse)
            
            """
        }
        
        // 构建任务文本
        var tasksText = ""
        if !tasks.isEmpty {
            let completed = tasks.filter { $0.status == "Completed" }
            let inProgress = tasks.filter { $0.status == "In Progress" }
            let pending = tasks.filter { $0.status == "Pending" }
            
            if !completed.isEmpty {
                tasksText += "Completed: " + completed.map { $0.name }.joined(separator: "、") + "\n"
            }
            if !inProgress.isEmpty {
                tasksText += "In Progress: " + inProgress.map { $0.name }.joined(separator: "、") + "\n"
            }
            if !pending.isEmpty {
                tasksText += "Pending: " + pending.map { $0.name }.joined(separator: "、") + "\n"
            }
        }
        
        // 是否需要合并提示
        let mergeHint = existingContent != nil ? """
        
        注意：需要整合之前已有的日志内容，将新内容与旧内容合并成一份完整的日志：
        ---
        \(existingContent ?? "")
        ---
        请生成整合后的完整总结，保留之前的重要信息并加入新内容，避免重复。
        """ : ""
        
        return """
        You are a professional work log assistant. Based on today's (\(dateString) chat logs, extract and organize valuable information.

        ⚠️ 重要规则：
        1. 只记录实际完成的事项、技术细节、想法和决策
        2. 忽略所有闲聊、情感关怀、喝水提醒等非工作内容
        3. 内容要具体、详细，包含技术细节和具体成果
        4. 适当用可爱语气，用简洁专业的记录风格

        今日对话记录：
        \(conversationsText)
        \(tasksText.isEmpty ? "" : "\n今日任务完成情况：\n\(tasksText)")
        \(mergeHint)

        请按以下 JSON 格式输出（只输出 JSON，不要其他文字）：
        {
            "title": "今日核心成就（不超过250字，具体明确）",
            "content": "详细记录，格式如下：\\n【完成事项】\\n• 事项1：具体做了什么\\n• 事项2：技术细节\\n【灵感/想法】\\n• 想法1\\n【明日计划】\\n• 计划1（可选）",
            "category": "Dev 或 Life 或 Idea 或 Random",
            "mood": "Happy 或 Neutral 或 Frustrated 或 Excited",
            "highlights": ["具体成就1", "具体成就2"]
        }

        分类说明：
        - Dev：开发、编程、技术相关
        - Life：日常生活、学习、健康
        - Idea：灵感、想法、创意
        - Random：其他话题

        情绪根据对话整体氛围判断：
        - Happy：完成目标、解决问题
        - Neutral：日常进展
        - Frustrated：遇到困难
        - Excited：有突破性进展
        """
    }
    
    private func buildPrompt(from logs: [ChatLogEntry]) -> String {
        return buildPromptWithTasks(from: logs, tasks: [], existingContent: nil)
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
    case saveError(String)
    case noDestination

    var errorDescription: String? {
        switch self {
        case .noConversations:
            return "No conversations recorded today!"
        case .parseError:
            return "Failed to parse AI response"
        case .saveError(let details):
            return "Save failed: \(details)"
        case .noDestination:
            return "No destination configured. Please set up Notion or Obsidian in Settings."
        }
    }
}
