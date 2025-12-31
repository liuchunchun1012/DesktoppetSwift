import Foundation
import AppKit

/// 聊天历史助手
/// 协助用户访问其他 AI 客户端的聊天记录目录
class ChatHistoryImporter {
    static let shared = ChatHistoryImporter()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Source Paths
    
    private var claudePath: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude")
    }
    
    private var antigravityPath: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/antigravity/conversations")
    }
    
    private var cursorPath: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor")
    }
    
    // MARK: - Public Methods
    
    /// 打开指定的目录
    func openFolder(for source: ImportSource) {
        let url: URL
        switch source {
        case .claudeDesktop: url = claudePath
        case .antigravity: url = antigravityPath
        case .cursor: url = cursorPath
        }
        
        if fileManager.fileExists(atPath: url.path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        }
    }
    
    /// 检查可用的导入源
    func getAvailableSources() -> [ImportSource] {
        var sources: [ImportSource] = []
        
        if fileManager.fileExists(atPath: claudePath.path) {
            sources.append(.claudeDesktop)
        }
        
        if fileManager.fileExists(atPath: antigravityPath.path) {
            sources.append(.antigravity)
        }
        
        if fileManager.fileExists(atPath: cursorPath.path) {
            sources.append(.cursor)
        }
        
        return sources
    }
    
    // 占位方法，保持编译通过但提示功能受限
    func importClaudeDesktop(completion: @escaping (Result<Int, Error>) -> Void) {
        completion(.failure(ImportError.formatNotSupported("二进制格式非常复杂，请点击按钮打开文件夹手动导出")))
    }
    
    func importAntigravity(completion: @escaping (Result<Int, Error>) -> Void) {
        completion(.failure(ImportError.formatNotSupported("二进制格式非常复杂，请点击按钮打开文件夹手动导出")))
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
    case formatNotSupported(String)
    
    var errorDescription: String? {
        switch self {
        case .obsidianNotConfigured:
            return "请先在设置中配置 Obsidian Vault 路径"
        case .sourceNotFound(let source):
            return "未找到 \(source) 的聊天记录"
        case .formatNotSupported(let message):
            return message
        }
    }
}
