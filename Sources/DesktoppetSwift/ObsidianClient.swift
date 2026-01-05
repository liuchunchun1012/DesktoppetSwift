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
            return "Obsidian 未配置，请在设置中填入 Vault 路径"
        case .noLogs:
            return "今天没有聊天记录"
        case .writeError(let message):
            return "写入失败: \(message)"
        }
    }
}
