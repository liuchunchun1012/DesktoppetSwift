import Foundation
import Combine

/// 用户设置管理器
/// 使用 UserDefaults 持久化非敏感配置
class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let currentProvider = "currentProvider"
        static let providerConfigs = "providerConfigs"
        static let translationLanguage = "translationLanguage"
        static let customSpritesPath = "customSpritesPath"
        static let useCustomSprites = "useCustomSprites"
        static let customChatPrompt = "customChatPrompt"
        static let customImagePrompt = "customImagePrompt"
        static let petName = "petName"
        static let petNickname = "petNickname"
        static let ownerName = "ownerName"
    }
    
    // MARK: - Published Properties
    
    /// 当前选择的 AI 提供商
    @Published var currentProvider: AIProviderType {
        didSet {
            defaults.set(currentProvider.rawValue, forKey: Keys.currentProvider)
        }
    }
    
    /// 翻译目标语言
    @Published var translationLanguage: TranslationLanguage {
        didSet {
            defaults.set(translationLanguage.rawValue, forKey: Keys.translationLanguage)
        }
    }
    
    /// 是否使用自定义精灵图
    @Published var useCustomSprites: Bool {
        didSet {
            defaults.set(useCustomSprites, forKey: Keys.useCustomSprites)
        }
    }
    
    /// 自定义精灵图路径
    @Published var customSpritesPath: String {
        didSet {
            defaults.set(customSpritesPath, forKey: Keys.customSpritesPath)
        }
    }
    
    /// 各提供商配置
    @Published var providerConfigs: [AIProviderType: ProviderConfiguration] {
        didSet {
            saveProviderConfigs()
        }
    }

    /// 自定义文本对话提示词（全局，所有 AI 提供商共用）
    @Published var customChatPrompt: String {
        didSet {
            defaults.set(customChatPrompt, forKey: Keys.customChatPrompt)
        }
    }

    /// 自定义图片分析提示词（全局，所有 AI 提供商共用）
    @Published var customImagePrompt: String {
        didSet {
            defaults.set(customImagePrompt, forKey: Keys.customImagePrompt)
        }
    }

    /// 宠物名称（全名）
    @Published var petName: String {
        didSet {
            defaults.set(petName, forKey: Keys.petName)
        }
    }

    /// 宠物昵称（小名）
    @Published var petNickname: String {
        didSet {
            defaults.set(petNickname, forKey: Keys.petNickname)
        }
    }

    /// 主人名称
    @Published var ownerName: String {
        didSet {
            defaults.set(ownerName, forKey: Keys.ownerName)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // 加载当前提供商
        if let providerRaw = defaults.string(forKey: Keys.currentProvider),
           let provider = AIProviderType(rawValue: providerRaw) {
            self.currentProvider = provider
        } else {
            self.currentProvider = .ollama
        }
        
        // 加载翻译语言
        if let langRaw = defaults.string(forKey: Keys.translationLanguage),
           let lang = TranslationLanguage(rawValue: langRaw) {
            self.translationLanguage = lang
        } else {
            self.translationLanguage = .chinese
        }
        
        // 加载精灵图设置
        self.useCustomSprites = defaults.bool(forKey: Keys.useCustomSprites)
        self.customSpritesPath = defaults.string(forKey: Keys.customSpritesPath) ?? ""

        // 加载宠物信息（首次运行时使用默认值）
        self.petName = defaults.string(forKey: Keys.petName) ?? PetConfig.petName
        self.petNickname = defaults.string(forKey: Keys.petNickname) ?? PetConfig.petNickname
        self.ownerName = defaults.string(forKey: Keys.ownerName) ?? PetConfig.ownerName

        // 加载自定义提示词（首次运行时使用默认值）
        if let savedChatPrompt = defaults.string(forKey: Keys.customChatPrompt) {
            self.customChatPrompt = savedChatPrompt
        } else {
            // 首次运行，使用 Config 中的默认提示词
            self.customChatPrompt = PetConfig.systemPrompt
            defaults.set(PetConfig.systemPrompt, forKey: Keys.customChatPrompt)
        }

        if let savedImagePrompt = defaults.string(forKey: Keys.customImagePrompt) {
            self.customImagePrompt = savedImagePrompt
        } else {
            // 首次运行，使用 Config 中的默认提示词
            self.customImagePrompt = PetConfig.imageAnalysisPrompt
            defaults.set(PetConfig.imageAnalysisPrompt, forKey: Keys.customImagePrompt)
        }

        // 加载提供商配置
        self.providerConfigs = [:]
        loadProviderConfigs()
    }
    
    // MARK: - Provider Configuration
    
    /// 获取指定提供商的配置
    func getConfig(for provider: AIProviderType) -> ProviderConfiguration {
        if let config = providerConfigs[provider] {
            return config
        }
        // 返回默认配置
        return ProviderConfiguration(type: provider)
    }
    
    /// 更新指定提供商的配置
    func updateConfig(_ config: ProviderConfiguration) {
        providerConfigs[config.type] = config
    }
    
    /// 获取当前提供商的模型
    func getCurrentModel() -> String {
        return getConfig(for: currentProvider).model
    }
    
    /// 设置当前提供商的模型
    func setCurrentModel(_ model: String) {
        var config = getConfig(for: currentProvider)
        config.model = model
        updateConfig(config)
    }
    
    /// 获取当前提供商的 Base URL
    func getCurrentBaseURL() -> String {
        return getConfig(for: currentProvider).baseURL
    }
    
    // MARK: - Private Methods
    
    private func saveProviderConfigs() {
        let encoder = JSONEncoder()
        var configsDict: [String: Data] = [:]
        
        for (type, config) in providerConfigs {
            if let data = try? encoder.encode(config) {
                configsDict[type.rawValue] = data
            }
        }
        
        defaults.set(configsDict, forKey: Keys.providerConfigs)
    }
    
    private func loadProviderConfigs() {
        guard let configsDict = defaults.dictionary(forKey: Keys.providerConfigs) as? [String: Data] else {
            // 初始化默认配置
            for type in AIProviderType.allCases {
                providerConfigs[type] = ProviderConfiguration(type: type)
            }
            return
        }
        
        let decoder = JSONDecoder()
        for (typeRaw, data) in configsDict {
            guard let type = AIProviderType(rawValue: typeRaw),
                  let config = try? decoder.decode(ProviderConfiguration.self, from: data) else {
                continue
            }
            providerConfigs[type] = config
        }
        
        // 确保所有类型都有配置
        for type in AIProviderType.allCases {
            if providerConfigs[type] == nil {
                providerConfigs[type] = ProviderConfiguration(type: type)
            }
        }
    }
    
    // MARK: - Reset
    
    /// 重置所有设置为默认值
    func resetToDefaults() {
        currentProvider = .ollama
        translationLanguage = .chinese
        useCustomSprites = false
        customSpritesPath = ""
        customChatPrompt = PetConfig.systemPrompt
        customImagePrompt = PetConfig.imageAnalysisPrompt
        petName = PetConfig.petName
        petNickname = PetConfig.petNickname
        ownerName = PetConfig.ownerName

        for type in AIProviderType.allCases {
            providerConfigs[type] = ProviderConfiguration(type: type)
        }
    }
}
