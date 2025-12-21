import Foundation

/// API Key 存储辅助类
/// 使用 UserDefaults 存储 API Key（避免 Keychain 权限弹窗问题）
class KeychainHelper {
    static let shared = KeychainHelper()
    
    private let defaults = UserDefaults.standard
    private let keyPrefix = "com.desktoppet.apikey."
    
    // 内存缓存
    private var cachedKeys: [String: String] = [:]
    
    private init() {
        // 启动时加载所有 API Key 到缓存
        loadAllKeys()
    }
    
    // MARK: - Public Methods
    
    /// 保存 API Key
    func save(key: String, value: String) throws {
        let fullKey = keyPrefix + key
        defaults.set(value, forKey: fullKey)
        cachedKeys[key] = value
    }
    
    /// 读取 API Key
    func read(key: String) -> String? {
        // 优先从缓存读取
        if let cached = cachedKeys[key] {
            return cached
        }
        
        let fullKey = keyPrefix + key
        if let value = defaults.string(forKey: fullKey) {
            cachedKeys[key] = value
            return value
        }
        return nil
    }
    
    /// 删除 API Key
    func delete(key: String) throws {
        let fullKey = keyPrefix + key
        defaults.removeObject(forKey: fullKey)
        cachedKeys.removeValue(forKey: key)
    }
    
    /// 检查 API Key 是否存在
    func exists(key: String) -> Bool {
        return read(key: key) != nil
    }
    
    // MARK: - Private Methods
    
    private func loadAllKeys() {
        for provider in AIProviderType.allCases {
            let key = Self.apiKeyName(for: provider)
            let fullKey = keyPrefix + key
            if let value = defaults.string(forKey: fullKey) {
                cachedKeys[key] = value
            }
        }
    }
    
    // MARK: - Convenience Methods for Providers
    
    /// 获取提供商的 API Key 键名
    static func apiKeyName(for provider: AIProviderType) -> String {
        return "\(provider.rawValue)_api_key"
    }
    
    /// 保存提供商的 API Key
    func saveAPIKey(_ apiKey: String, for provider: AIProviderType) throws {
        try save(key: KeychainHelper.apiKeyName(for: provider), value: apiKey)
    }
    
    /// 读取提供商的 API Key
    func getAPIKey(for provider: AIProviderType) -> String? {
        return read(key: KeychainHelper.apiKeyName(for: provider))
    }
    
    /// 删除提供商的 API Key
    func deleteAPIKey(for provider: AIProviderType) throws {
        try delete(key: KeychainHelper.apiKeyName(for: provider))
    }
}

// MARK: - Keychain Errors (保留兼容性)

enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode API key"
        case .saveFailed(let status):
            return "Failed to save: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete: \(status)"
        }
    }
}
