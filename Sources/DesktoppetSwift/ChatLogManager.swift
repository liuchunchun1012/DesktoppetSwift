import Foundation

/// 聊天记录条目
struct ChatLogEntry: Identifiable, Codable {
    let id: UUID
    let userMessage: String
    let aiResponse: String
    let timestamp: Date
    var syncedToNotion: Bool
    
    init(userMessage: String, aiResponse: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.userMessage = userMessage
        self.aiResponse = aiResponse
        self.timestamp = timestamp
        self.syncedToNotion = false
    }
}

/// 聊天记录管理器
/// 使用 iCloud Drive 文件同步（直接写入 iCloud Drive 目录）
class ChatLogManager: ObservableObject {
    static let shared = ChatLogManager()
    
    @Published private(set) var todayLogs: [ChatLogEntry] = []
    
    private let fileManager = FileManager.default
    
    // iCloud Drive 目录（直接路径，不使用 API）
    // ~/Library/Mobile Documents/com~apple~CloudDocs/DesktoppetSwift/ChatLogs/
    private var storageDirectory: URL {
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let iCloudDocs = homeDir
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/DesktoppetSwift/ChatLogs")
        
        // 确保目录存在
        if !fileManager.fileExists(atPath: iCloudDocs.path) {
            do {
                try fileManager.createDirectory(at: iCloudDocs, withIntermediateDirectories: true)
                print("[ChatLogManager] Created iCloud directory: \(iCloudDocs.path)")
            } catch {
                print("[ChatLogManager] Failed to create iCloud directory: \(error)")
                // 回退到本地目录
                return localFallbackDirectory
            }
        }
        
        return iCloudDocs
    }
    
    // 本地回退目录
    private var localFallbackDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("DesktoppetSwift/ChatLogs", isDirectory: true)
        try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder
    }
    
    // 记录当前加载的日期，用于检测日期变化
    private var loadedDate: String = ""
    
    // 获取今天的日期字符串
    private var todayDateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: Date())
    }
    
    // 今日日志文件路径
    private var todayLogURL: URL {
        let fileName = "chatlog_\(todayDateString).json"
        return storageDirectory.appendingPathComponent(fileName)
    }
    
    private init() {
        print("[ChatLogManager] Storage: \(storageDirectory.path)")
        loadedDate = todayDateString
        loadTodayLogs()
    }
    
    // MARK: - Public Methods
    
    /// 记录一次对话
    func logConversation(userMessage: String, aiResponse: String) {
        checkDateChange()
        let entry = ChatLogEntry(userMessage: userMessage, aiResponse: aiResponse)
        todayLogs.append(entry)
        saveTodayLogs()
        print("[ChatLogManager] Logged: \(userMessage.prefix(30))...")
    }
    
    /// 获取今日所有对话
    func getTodayConversations() -> [ChatLogEntry] {
        checkDateChange()
        return todayLogs
    }
    
    /// 获取未同步到 Notion 的对话
    func getUnsyncedToNotion() -> [ChatLogEntry] {
        checkDateChange()
        return todayLogs.filter { !$0.syncedToNotion }
    }
    
    /// 检查日期是否变化，如果变化则重新加载
    private func checkDateChange() {
        if loadedDate != todayDateString {
            print("[ChatLogManager] Date changed from \(loadedDate) to \(todayDateString), reloading...")
            loadedDate = todayDateString
            loadTodayLogs()
        }
    }
    
    /// 标记对话已同步到 Notion
    func markSyncedToNotion() {
        for i in todayLogs.indices {
            todayLogs[i].syncedToNotion = true
        }
        saveTodayLogs()
    }
    
    /// 刷新（从 iCloud 重新加载）
    func refresh() {
        loadTodayLogs()
    }
    
    // MARK: - Private Methods
    
    private func loadTodayLogs() {
        guard fileManager.fileExists(atPath: todayLogURL.path) else {
            todayLogs = []
            return
        }
        
        do {
            let data = try Data(contentsOf: todayLogURL)
            todayLogs = try JSONDecoder().decode([ChatLogEntry].self, from: data)
            print("[ChatLogManager] Loaded \(todayLogs.count) logs")
        } catch {
            print("[ChatLogManager] Load failed: \(error)")
            todayLogs = []
        }
    }
    
    private func saveTodayLogs() {
        do {
            let data = try JSONEncoder().encode(todayLogs)
            try data.write(to: todayLogURL)
        } catch {
            print("[ChatLogManager] Save failed: \(error)")
        }
    }
}
