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
    func writeNote(title: String, content: String, folder: String? = nil, tags: [String] = [], completion: @escaping (Result<Void, Error>) -> Void) {
        guard isConfigured() else {
            completion(.failure(ObsidianError.notConfigured))
            return
        }
        
        let frontmatter = buildFrontmatter(tags: tags)
        let fullContent = "\(frontmatter)\n\n# \(title)\n\n\(content)"
        let fileName = sanitizeFileName(title) + ".md"
        
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
    
    // MARK: - Private Methods
    
    private func vaultURL() -> URL {
        URL(fileURLWithPath: UserSettings.shared.obsidianVaultPath)
    }
    
    private func chatLogFolder() -> String {
        let folder = UserSettings.shared.obsidianChatLogFolder
        return folder.isEmpty ? "ChatLogs" : folder
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
        
        var tagsString = tags.isEmpty ? "" : "tags: [\(tags.joined(separator: ", "))]"
        
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
            return "Obsidian 未配置，请在设置中填入 Vault 路径"
        case .noLogs:
            return "今天没有聊天记录"
        case .writeError(let message):
            return "写入失败: \(message)"
        }
    }
}
