import Foundation
import CloudKit

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
/// 负责本地存储和 iCloud 同步（为未来 iOS 版本预留）
class ChatLogManager: ObservableObject {
    static let shared = ChatLogManager()
    
    @Published private(set) var todayLogs: [ChatLogEntry] = []
    
    private let fileManager = FileManager.default
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    // CloudKit 记录类型
    private let recordType = "ChatLog"
    
    // 本地缓存路径
    private var localCacheURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("DesktoppetSwift", isDirectory: true)
        
        // 确保目录存在
        try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "chatlog_\(dateFormatter.string(from: Date())).json"
        
        return appFolder.appendingPathComponent(fileName)
    }
    
    private init() {
        // 初始化 CloudKit 容器
        // 注意：需要在 Xcode 中配置 iCloud 能力和容器标识符
        container = CKContainer(identifier: "iCloud.com.desktoppet.swift")
        privateDatabase = container.privateCloudDatabase
        
        // 加载今日本地缓存
        loadTodayLogs()
    }
    
    // MARK: - Public Methods
    
    /// 记录一次对话
    func logConversation(userMessage: String, aiResponse: String) {
        let entry = ChatLogEntry(userMessage: userMessage, aiResponse: aiResponse)
        todayLogs.append(entry)
        
        // 保存到本地
        saveTodayLogs()
        
        // 异步同步到 iCloud
        syncToCloud(entry)
        
        print("[ChatLogManager] Logged conversation: \(userMessage.prefix(30))...")
    }
    
    /// 获取今日所有对话（用于生成总结）
    func getTodayConversations() -> [ChatLogEntry] {
        return todayLogs
    }
    
    /// 获取未同步到 Notion 的对话
    func getUnsyncedToNotion() -> [ChatLogEntry] {
        return todayLogs.filter { !$0.syncedToNotion }
    }
    
    /// 标记对话已同步到 Notion
    func markSyncedToNotion() {
        for i in todayLogs.indices {
            todayLogs[i].syncedToNotion = true
        }
        saveTodayLogs()
    }
    
    /// 清理旧日志（保留最近 7 天）
    func cleanupOldLogs() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("DesktoppetSwift", isDirectory: true)
        
        guard let files = try? fileManager.contentsOfDirectory(at: appFolder, includingPropertiesForKeys: nil) else {
            return
        }
        
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        for file in files where file.lastPathComponent.hasPrefix("chatlog_") {
            if let dateString = file.lastPathComponent.split(separator: "_").last?.replacingOccurrences(of: ".json", with: ""),
               let fileDate = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none) as String?,
               let date = DateFormatter().date(from: String(dateString)),
               date < sevenDaysAgo {
                try? fileManager.removeItem(at: file)
                print("[ChatLogManager] Cleaned up old log: \(file.lastPathComponent)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadTodayLogs() {
        guard fileManager.fileExists(atPath: localCacheURL.path) else {
            todayLogs = []
            return
        }
        
        do {
            let data = try Data(contentsOf: localCacheURL)
            todayLogs = try JSONDecoder().decode([ChatLogEntry].self, from: data)
            print("[ChatLogManager] Loaded \(todayLogs.count) logs from cache")
        } catch {
            print("[ChatLogManager] Failed to load cache: \(error)")
            todayLogs = []
        }
    }
    
    private func saveTodayLogs() {
        do {
            let data = try JSONEncoder().encode(todayLogs)
            try data.write(to: localCacheURL)
        } catch {
            print("[ChatLogManager] Failed to save cache: \(error)")
        }
    }
    
    private func syncToCloud(_ entry: ChatLogEntry) {
        let record = CKRecord(recordType: recordType)
        record["userMessage"] = entry.userMessage as CKRecordValue
        record["aiResponse"] = entry.aiResponse as CKRecordValue
        record["timestamp"] = entry.timestamp as CKRecordValue
        record["syncedToNotion"] = entry.syncedToNotion as CKRecordValue
        record["entryId"] = entry.id.uuidString as CKRecordValue
        
        privateDatabase.save(record) { savedRecord, error in
            if let error = error {
                // CloudKit 错误不阻塞主流程，只记录日志
                print("[ChatLogManager] CloudKit sync failed: \(error.localizedDescription)")
            } else {
                print("[ChatLogManager] Synced to iCloud successfully")
            }
        }
    }
    
    /// 从 iCloud 拉取数据（启动时或手动刷新时调用）
    func fetchFromCloud() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let predicate = NSPredicate(format: "timestamp >= %@", startOfDay as NSDate)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        privateDatabase.perform(query, inZoneWith: nil) { [weak self] records, error in
            if let error = error {
                print("[ChatLogManager] CloudKit fetch failed: \(error.localizedDescription)")
                return
            }
            
            guard let records = records, !records.isEmpty else { return }
            
            DispatchQueue.main.async {
                // 合并云端数据（避免重复）
                let existingIds = Set(self?.todayLogs.map { $0.id.uuidString } ?? [])
                
                for record in records {
                    guard let entryIdString = record["entryId"] as? String,
                          !existingIds.contains(entryIdString),
                          let userMessage = record["userMessage"] as? String,
                          let aiResponse = record["aiResponse"] as? String,
                          let timestamp = record["timestamp"] as? Date else {
                        continue
                    }
                    
                    var entry = ChatLogEntry(userMessage: userMessage, aiResponse: aiResponse, timestamp: timestamp)
                    if let synced = record["syncedToNotion"] as? Bool {
                        entry.syncedToNotion = synced
                    }
                    
                    self?.todayLogs.append(entry)
                }
                
                self?.todayLogs.sort { $0.timestamp < $1.timestamp }
                self?.saveTodayLogs()
                
                print("[ChatLogManager] Merged \(records.count) records from iCloud")
            }
        }
    }
}
