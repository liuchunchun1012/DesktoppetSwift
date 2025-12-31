import Foundation

/// 聊天历史导入器
/// 支持从 Claude Desktop, Cursor, Antigravity 导入聊天记录到 Obsidian
class ChatHistoryImporter {
    static let shared = ChatHistoryImporter()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Source Paths
    
    private var claudeProjectsPath: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
    }
    
    private var antigravityConversationsPath: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".gemini/antigravity/conversations")
    }
    
    // MARK: - Public Methods
    
    /// 导入 Claude Desktop 聊天记录
    func importClaudeDesktop(completion: @escaping (Result<Int, Error>) -> Void) {
        guard ObsidianClient.shared.isConfigured() else {
            completion(.failure(ImportError.obsidianNotConfigured))
            return
        }
        
        guard fileManager.fileExists(atPath: claudeProjectsPath.path) else {
            completion(.failure(ImportError.sourceNotFound("Claude Desktop")))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let count = try self.parseAndExportClaude()
                DispatchQueue.main.async {
                    completion(.success(count))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 导入 Antigravity 聊天记录
    func importAntigravity(completion: @escaping (Result<Int, Error>) -> Void) {
        guard ObsidianClient.shared.isConfigured() else {
            completion(.failure(ImportError.obsidianNotConfigured))
            return
        }
        
        guard fileManager.fileExists(atPath: antigravityConversationsPath.path) else {
            completion(.failure(ImportError.sourceNotFound("Antigravity")))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let count = try self.parseAndExportAntigravity()
                DispatchQueue.main.async {
                    completion(.success(count))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 检查可用的导入源
    func getAvailableSources() -> [ImportSource] {
        var sources: [ImportSource] = []
        
        if fileManager.fileExists(atPath: claudeProjectsPath.path) {
            sources.append(.claudeDesktop)
        }
        
        if fileManager.fileExists(atPath: antigravityConversationsPath.path) {
            sources.append(.antigravity)
        }
        
        return sources
    }
    
    // MARK: - Claude Desktop Parser
    
    private func parseAndExportClaude() throws -> Int {
        var totalCount = 0
        
        // 遍历 ~/.claude/projects/ 下的所有项目
        let projectDirs = try fileManager.contentsOfDirectory(at: claudeProjectsPath, includingPropertiesForKeys: nil)
        
        for projectDir in projectDirs {
            guard projectDir.hasDirectoryPath else { continue }
            
            // 查找 JSONL 文件
            let jsonlFiles = try fileManager.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "jsonl" }
            
            for jsonlFile in jsonlFiles {
                let conversations = try parseClaudeJSONL(at: jsonlFile)
                if !conversations.isEmpty {
                    try exportToObsidian(conversations: conversations, source: "Claude", projectName: projectDir.lastPathComponent)
                    totalCount += conversations.count
                }
            }
        }
        
        return totalCount
    }
    
    private func parseClaudeJSONL(at url: URL) throws -> [(timestamp: Date, user: String, assistant: String)] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var conversations: [(timestamp: Date, user: String, assistant: String)] = []
        var currentUser: String?
        var currentTimestamp: Date = Date()
        
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            // Claude JSONL 格式: {"role": "user/assistant", "content": "...", ...}
            guard let role = json["role"] as? String,
                  let content = json["content"] as? String else {
                continue
            }
            
            if let timestampStr = json["timestamp"] as? String {
                let formatter = ISO8601DateFormatter()
                currentTimestamp = formatter.date(from: timestampStr) ?? Date()
            }
            
            if role == "user" || role == "human" {
                currentUser = content
            } else if role == "assistant" && currentUser != nil {
                conversations.append((currentTimestamp, currentUser!, content))
                currentUser = nil
            }
        }
        
        return conversations
    }
    
    // MARK: - Antigravity Parser
    
    private func parseAndExportAntigravity() throws -> Int {
        var totalCount = 0
        
        // 遍历 conversations 目录下的 .pb 文件
        let pbFiles = try fileManager.contentsOfDirectory(at: antigravityConversationsPath, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "pb" }
        
        for pbFile in pbFiles {
            let conversations = try parseAntigravityProtobuf(at: pbFile)
            if !conversations.isEmpty {
                let sessionId = pbFile.deletingPathExtension().lastPathComponent
                try exportToObsidian(conversations: conversations, source: "Antigravity", projectName: sessionId)
                totalCount += conversations.count
            }
        }
        
        return totalCount
    }
    
    private func parseAntigravityProtobuf(at url: URL) throws -> [(timestamp: Date, user: String, assistant: String)] {
        // Read binary data and try to extract readable text
        let data = try Data(contentsOf: url)
        
        // Get file modification date as timestamp
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        let fileDate = attrs[.modificationDate] as? Date ?? Date()
        
        // Extract readable strings from protobuf
        // This is a simplified approach - protobuf embeds strings with length prefixes
        let textContent = extractTextFromProtobuf(data)
        
        guard !textContent.isEmpty else {
            return []
        }
        
        // Parse the extracted text to find user/assistant pairs
        return parseConversationText(textContent, date: fileDate)
    }
    
    private func extractTextFromProtobuf(_ data: Data) -> String {
        // Protobuf stores strings as: field_tag + length + utf8_bytes
        // We'll try to extract readable UTF-8 strings
        var strings: [String] = []
        var index = 0
        let bytes = [UInt8](data)
        
        while index < bytes.count {
            // Look for potential string starts (printable ASCII or UTF-8)
            var stringStart = index
            var validChars = 0
            
            while index < bytes.count {
                let byte = bytes[index]
                // Check if byte is printable or valid UTF-8
                if (byte >= 0x20 && byte < 0x7F) || byte >= 0xC0 {
                    validChars += 1
                    index += 1
                } else if validChars > 10 { // Minimum useful string length
                    break
                } else {
                    index += 1
                    stringStart = index
                    validChars = 0
                }
            }
            
            if validChars > 10 {
                if let str = String(bytes: bytes[stringStart..<index], encoding: .utf8) {
                    strings.append(str)
                }
            }
            index += 1
        }
        
        return strings.joined(separator: "\n")
    }
    
    private func parseConversationText(_ text: String, date: Date) -> [(timestamp: Date, user: String, assistant: String)] {
        // Look for patterns that suggest user/assistant turns
        // This is heuristic-based
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        if lines.isEmpty {
            return []
        }
        
        // Return as single conversation summary
        return [(date, "Antigravity Session", text.prefix(5000).description)]
    }
    
    // MARK: - Export to Obsidian
    
    private func exportToObsidian(conversations: [(timestamp: Date, user: String, assistant: String)], source: String, projectName: String) throws {
        let vaultPath = UserSettings.shared.obsidianVaultPath
        let chatLogFolder = UserSettings.shared.obsidianChatLogFolder
        
        // Create source subdirectory
        let sourceFolder = URL(fileURLWithPath: vaultPath)
            .appendingPathComponent(chatLogFolder)
            .appendingPathComponent(source)
        
        try fileManager.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        
        // Group by date
        let grouped = Dictionary(grouping: conversations) { conv -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: conv.timestamp)
        }
        
        for (dateString, convs) in grouped {
            let fileName = "\(dateString)-\(sanitizeFileName(projectName)).md"
            let fileURL = sourceFolder.appendingPathComponent(fileName)
            
            var markdown = """
            ---
            date: \(dateString)
            source: \(source.lowercased())
            project: \(projectName)
            tags: [ai, chat, imported, \(source.lowercased())]
            ---
            
            # \(source) 聊天记录 - \(dateString)
            
            """
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            
            for conv in convs {
                markdown += """
                
                ## \(timeFormatter.string(from: conv.timestamp))
                
                **我：** \(conv.user.prefix(500))...
                
                **AI：** \(conv.assistant.prefix(1000))...
                
                ---
                
                """
            }
            
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?*\"<>|")
        var sanitized = name.components(separatedBy: invalidChars).joined(separator: "_")
        // Shorten path-like names
        if sanitized.contains("-Users-") {
            sanitized = sanitized.components(separatedBy: "-").last ?? sanitized
        }
        return String(sanitized.prefix(50))
    }
}

// MARK: - Supporting Types

enum ImportSource: String, CaseIterable {
    case claudeDesktop = "Claude Desktop"
    case antigravity = "Antigravity"
    case cursor = "Cursor"
    
    var icon: String {
        switch self {
        case .claudeDesktop: return "message"
        case .antigravity: return "sparkles"
        case .cursor: return "cursorarrow.rays"
        }
    }
}

enum ImportError: Error, LocalizedError {
    case obsidianNotConfigured
    case sourceNotFound(String)
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .obsidianNotConfigured:
            return "请先在设置中配置 Obsidian Vault 路径"
        case .sourceNotFound(let source):
            return "未找到 \(source) 的聊天记录"
        case .parseError(let message):
            return "解析错误: \(message)"
        }
    }
}
