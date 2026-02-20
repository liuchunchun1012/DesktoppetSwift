import Foundation

/// Obsidian 客户端
/// 将聊天记录和笔记写入 Obsidian Vault
class ObsidianClient {
    static let shared = ObsidianClient()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 同步今日聊天记录到 Obsidian
    func syncTodayChatLogs(completion: @escaping (Result<String, Error>) -> Void) {
        guard isConfigured() else {
            completion(.failure(ObsidianError.notConfigured))
            return
        }
        
        let logs = ChatLogManager.shared.getTodayConversations()
        guard !logs.isEmpty else {
            completion(.failure(ObsidianError.noLogs))
            return
        }
        
        let markdown = buildChatLogMarkdown(logs: logs)
        let fileName = todayFileName()
        
        do {
            try writeToVault(content: markdown, fileName: fileName, folder: chatLogFolder())
            completion(.success(fileName))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 写入任意内容到 Obsidian
    func writeNote(title: String, content: String, folder: String? = nil, tags: [String] = [], customFileName: String? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isConfigured() else {
            completion(.failure(ObsidianError.notConfigured))
            return
        }
        
        // 如果传入了完整内容（已包含 frontmatter），直接使用
        let fullContent: String
        if content.hasPrefix("---") {
            fullContent = content
        } else {
            let frontmatter = buildFrontmatter(tags: tags)
            fullContent = "\(frontmatter)\n\n# \(title)\n\n\(content)"
        }
        
        let fileName = customFileName ?? (sanitizeFileName(title) + ".md")
        
        do {
            try writeToVault(content: fullContent, fileName: fileName, folder: folder)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 检查是否已配置
    func isConfigured() -> Bool {
        let vaultPath = UserSettings.shared.obsidianVaultPath
        return !vaultPath.isEmpty && fileManager.fileExists(atPath: vaultPath)
    }
    
    /// 测试连接
    func testConnection(completion: @escaping (Result<Void, Error>) -> Void) {
        guard isConfigured() else {
            completion(.failure(ObsidianError.notConfigured))
            return
        }
        
        let vaultPath = UserSettings.shared.obsidianVaultPath
        let testFile = URL(fileURLWithPath: vaultPath).appendingPathComponent(".obsidian-test")
        
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
            completion(.success(()))
        } catch {
            completion(.failure(ObsidianError.writeError(error.localizedDescription)))
        }
    }
    /// 快速保存内容到 Obsidian
    /// - Parameters:
    ///   - content: 要保存的内容
    ///   - title: 可选标题，默认使用时间戳
    func quickSave(content: String, title: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard isConfigured() else {
            completion(.failure(ObsidianError.notConfigured))
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        
        let noteTitle = title ?? "快速笔记 - \(timestamp)"
        let fileName = sanitizeFileName(noteTitle) + ".md"
        
        let markdown = """
        ---
        created: \(timestamp)
        tags: [小猫, quick-note]
        ---
        
        # \(noteTitle)
        
        \(content)
        """
        
        do {
            try writeToVault(content: markdown, fileName: fileName, folder: quickSaveFolder())
            print("[ObsidianClient] Quick saved: \(fileName)")
            completion(.success(fileName))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 快速保存内容到 Obsidian（包含图片）
    /// - Parameters:
    ///   - content: 要保存的 Markdown 内容
    ///   - imageBase64: 图片的 Base64 编码
    ///   - title: 可选标题
    func quickSaveWithImage(content: String, imageBase64: String, title: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard isConfigured() else {
            completion(.failure(ObsidianError.notConfigured))
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        
        let noteTitle = title ?? "快速笔记 - \(timestamp)"
        let mdFileName = sanitizeFileName(noteTitle) + ".md"
        let imageFileName = sanitizeFileName(noteTitle) + ".png"
        let imageSubfolder = "quickscreenshots"
        
        // 保存图片文件到子文件夹
        do {
            // 确保子文件夹路径: quickSaveRoot/quickscreenshots/
            let fullImageFolder = (quickSaveFolder() as NSString).appendingPathComponent(imageSubfolder)
            try saveImage(base64: imageBase64, fileName: imageFileName, folder: fullImageFolder)
        } catch {
            completion(.failure(error))
            return
        }
        
        // 在 markdown 中嵌入图片引用 (使用 Obsidian Wiki Link 格式)
        let markdown = """
        ---
        created: \(timestamp)
        tags: [小猫, quick-note, image]
        ---
        
        # \(noteTitle)
        
        \(content)
        
        ![[\(imageSubfolder)/\(imageFileName)]]
        """
        
        do {
            try writeToVault(content: markdown, fileName: mdFileName, folder: quickSaveFolder())
            print("[ObsidianClient] Quick saved with image: \(mdFileName)")
            completion(.success(mdFileName))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 保存 Base64 图片到 Vault
    private func saveImage(base64: String, fileName: String, folder: String) throws {
        guard let imageData = Data(base64Encoded: base64) else {
            throw ObsidianError.writeError("无法解码图片数据")
        }
        
        var targetURL = vaultURL()
        if !folder.isEmpty {
            targetURL = targetURL.appendingPathComponent(folder)
            if !fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
            }
        }
        
        let fileURL = targetURL.appendingPathComponent(fileName)
        try imageData.write(to: fileURL)
        print("[ObsidianClient] Saved image: \(fileURL.path)")
    }
    
    private func quickSaveFolder() -> String {
        let folder = UserSettings.shared.obsidianQuickSaveFolder
        return folder.isEmpty ? "QuickNotes" : folder
    }

    // MARK: - Daily Summary Methods

    /// 保存每日总结到 Obsidian Daily Notes
    func saveDailySummary(_ summary: DailySummary, completion: @escaping (Result<String, Error>) -> Void) {
        guard isConfigured() else {
            completion(.failure(ObsidianError.notConfigured))
            return
        }

        let folder = UserSettings.shared.obsidianDailyNotesFolder
        let fileName = dailyNoteFileName()
        let content = formatDailySummary(summary)

        do {
            try writeOrAppendDailyNote(content: content, fileName: fileName, folder: folder)
            print("[ObsidianClient] Daily summary saved: \(fileName)")
            completion(.success(fileName))
        } catch {
            completion(.failure(error))
        }
    }

    /// 格式化每日总结为 Markdown
    private func formatDailySummary(_ summary: DailySummary) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: Date())

        var markdown = """
        ## \(timeString) - \(summary.title)

        \(summary.content)

        """

        if !summary.highlights.isEmpty {
            markdown += "**Highlights:** " + summary.highlights.joined(separator: ", ") + "\n\n"
        }

        markdown += "**Mood:** \(summary.mood) | **Category:** \(summary.category)\n\n---\n"

        return markdown
    }

    /// 获取今日 Daily Note 文件名
    private func dailyNoteFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date()) + ".md"
    }

    /// 写入或追加到 Daily Note
    private func writeOrAppendDailyNote(content: String, fileName: String, folder: String) throws {
        var targetURL = vaultURL()
        if !folder.isEmpty {
            targetURL = targetURL.appendingPathComponent(folder)
            if !fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
            }
        }

        let fileURL = targetURL.appendingPathComponent(fileName)

        // 如果文件不存在，创建带标题的新文件
        if !fileManager.fileExists(atPath: fileURL.path) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: Date())

            let header = """
            ---
            date: \(dateString)
            tags: [daily-note, meowpal]
            ---

            # \(dateString)

            """
            try header.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // 读取现有内容并追加
        var existingContent = try String(contentsOf: fileURL, encoding: .utf8)
        if !existingContent.hasSuffix("\n") {
            existingContent += "\n"
        }
        existingContent += content

        try existingContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Task Methods

    /// 保存任务到 Obsidian (Obsidian Tasks 格式)
    /// 格式: - [ ] Task name 📅 2025-01-20 ⏰ 15:00
    func saveTask(_ task: TodoTask, completion: @escaping (Result<String, Error>) -> Void) {
        guard isConfigured() else {
            completion(.failure(ObsidianError.notConfigured))
            return
        }

        let tasksFile = UserSettings.shared.obsidianTasksFile
        let taskLine = formatTaskLine(task)

        do {
            try appendToTasksFile(taskLine, fileName: tasksFile)
            print("[ObsidianClient] Task saved: \(task.name)")
            completion(.success(tasksFile))
        } catch {
            completion(.failure(error))
        }
    }

    /// 格式化任务为 Obsidian Tasks 格式
    private func formatTaskLine(_ task: TodoTask) -> String {
        var line = "- [ ] \(task.name)"

        // 添加日期 📅
        if let dueDate = task.dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            line += " 📅 \(formatter.string(from: dueDate))"
        } else if let startDate = task.startDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            line += " 📅 \(formatter.string(from: startDate))"
        }

        // 添加时间 ⏰ (如果有具体时间)
        if let startDate = task.startDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let timeStr = formatter.string(from: startDate)
            if timeStr != "00:00" {
                line += " ⏰ \(timeStr)"
            }
        }

        // 添加优先级标签
        if task.priority == "高" || task.priority == "High" {
            line += " ⏫"
        } else if task.priority == "低" || task.priority == "Low" {
            line += " 🔽"
        }

        return line
    }

    /// 追加内容到任务文件
    private func appendToTasksFile(_ content: String, fileName: String) throws {
        let fileURL = vaultURL().appendingPathComponent(fileName)

        // 如果文件不存在，创建带标题的新文件
        if !fileManager.fileExists(atPath: fileURL.path) {
            let header = "# Tasks\n\n"
            try header.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // 读取现有内容并追加
        var existingContent = try String(contentsOf: fileURL, encoding: .utf8)
        if !existingContent.hasSuffix("\n") {
            existingContent += "\n"
        }
        existingContent += content + "\n"

        try existingContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Private Methods
    
    private func vaultURL() -> URL {
        URL(fileURLWithPath: UserSettings.shared.obsidianVaultPath)
    }
    
    private func chatLogFolder() -> String {
        let baseFolder = UserSettings.shared.obsidianChatLogFolder
        let folder = baseFolder.isEmpty ? "ChatLogs" : baseFolder
        // Add 小猫 subdirectory for consistency with other sources like Claude, Antigravity
        return folder + "/小猫"
    }
    
    private func todayFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date()) + ".md"
    }
    
    private func writeToVault(content: String, fileName: String, folder: String?) throws {
        var targetURL = vaultURL()
        
        // 创建子文件夹
        if let folder = folder, !folder.isEmpty {
            targetURL = targetURL.appendingPathComponent(folder)
            if !fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
            }
        }
        
        let fileURL = targetURL.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        print("[ObsidianClient] Written: \(fileURL.path)")
    }
    
    private func buildChatLogMarkdown(logs: [ChatLogEntry]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        var markdown = """
        ---
        date: \(dateString)
        tags: [ai, chat, 小猫]
        ---

        # 小猫聊天记录 - \(dateString)

        """
        
        for log in logs {
            let time = timeFormatter.string(from: log.timestamp)
            markdown += """
            
            ## \(time)
            
            **我：** \(log.userMessage)
            
            **小猫：** \(log.aiResponse)
            
            ---
            
            """
        }
        
        return markdown
    }
    
    private func buildFrontmatter(tags: [String]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateString = formatter.string(from: Date())
        
        let tagsString = tags.isEmpty ? "" : "tags: [\(tags.joined(separator: ", "))]"
        
        return """
        ---
        created: \(dateString)
        \(tagsString)
        ---
        """
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?*\"<>|")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }
}

// MARK: - Errors

enum ObsidianError: Error, LocalizedError {
    case notConfigured
    case noLogs
    case writeError(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Obsidian not configured. Please set Vault path in Settings"
        case .noLogs:
            return "No chat logs today"
        case .writeError(let message):
            return "写入失败: \(message)"
        }
    }
}
