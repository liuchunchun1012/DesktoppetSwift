import Foundation
import Combine
import Carbon

/// 快捷键配置结构
struct HotkeyConfig: Codable, Equatable {
    let keyCode: Int
    let modifiers: Int  // Carbon modifiers: cmdKey=256, shiftKey=512, etc.
    
    /// 默认快捷键配置
    static let defaultChat = HotkeyConfig(keyCode: kVK_ANSI_J, modifiers: cmdKey | shiftKey)
    static let defaultTranslate = HotkeyConfig(keyCode: kVK_ANSI_T, modifiers: cmdKey | shiftKey)
    static let defaultImage = HotkeyConfig(keyCode: kVK_ANSI_L, modifiers: cmdKey | shiftKey)
    static let defaultSelection = HotkeyConfig(keyCode: kVK_ANSI_S, modifiers: cmdKey | shiftKey)
    
    /// 显示用的快捷键字符串
    var displayString: String {
        var parts: [String] = []
        if modifiers & cmdKey != 0 { parts.append("⌘") }
        if modifiers & shiftKey != 0 { parts.append("⇧") }
        if modifiers & optionKey != 0 { parts.append("⌥") }
        if modifiers & controlKey != 0 { parts.append("⌃") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }
    
    /// keyCode 转换为可显示字符
    private func keyCodeToString(_ code: Int) -> String {
        switch code {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        default: return "?"
        }
    }
}

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
        static let notionEnabled = "notionEnabled"
        static let notionDatabaseId = "notionDatabaseId"
        static let todoListDatabaseId = "todoListDatabaseId"
        static let obsidianEnabled = "obsidianEnabled"
        static let obsidianVaultPath = "obsidianVaultPath"
        static let obsidianChatLogFolder = "obsidianChatLogFolder"
        static let obsidianQuickSaveFolder = "obsidianQuickSaveFolder"
        static let selectionAssistantEnabled = "selectionAssistantEnabled"
        // 快捷键配置
        static let hotkeyChat = "hotkeyChat"
        static let hotkeyTranslate = "hotkeyTranslate"
        static let hotkeyImage = "hotkeyImage"
        static let hotkeySelection = "hotkeySelection"
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
    
    /// 是否启用 Notion 同步
    @Published var notionEnabled: Bool {
        didSet {
            defaults.set(notionEnabled, forKey: Keys.notionEnabled)
        }
    }
    
    /// Notion Database ID (日志)
    @Published var notionDatabaseId: String {
        didSet {
            defaults.set(notionDatabaseId, forKey: Keys.notionDatabaseId)
        }
    }
    
    /// TodoList Database ID
    @Published var todoListDatabaseId: String {
        didSet {
            defaults.set(todoListDatabaseId, forKey: Keys.todoListDatabaseId)
        }
    }
    
    /// 是否启用 Obsidian 同步
    @Published var obsidianEnabled: Bool {
        didSet {
            defaults.set(obsidianEnabled, forKey: Keys.obsidianEnabled)
        }
    }
    
    /// Obsidian Vault 路径
    @Published var obsidianVaultPath: String {
        didSet {
            defaults.set(obsidianVaultPath, forKey: Keys.obsidianVaultPath)
        }
    }
    
    /// Obsidian 聊天记录文件夹
    @Published var obsidianChatLogFolder: String {
        didSet {
            defaults.set(obsidianChatLogFolder, forKey: Keys.obsidianChatLogFolder)
        }
    }
    
    /// Obsidian 快速保存文件夹
    @Published var obsidianQuickSaveFolder: String {
        didSet {
            defaults.set(obsidianQuickSaveFolder, forKey: Keys.obsidianQuickSaveFolder)
        }
    }
    
    /// 是否启用划词助手
    @Published var selectionAssistantEnabled: Bool {
        didSet {
            defaults.set(selectionAssistantEnabled, forKey: Keys.selectionAssistantEnabled)
            // 根据设置开启或关闭
            if selectionAssistantEnabled {
                TextSelectionAssistant.shared.enable()
            } else {
                TextSelectionAssistant.shared.disable()
            }
        }
    }
    
    // MARK: - 快捷键配置
    
    /// 对话快捷键 (默认: J)
    @Published var hotkeyChat: HotkeyConfig {
        didSet {
            if let data = try? JSONEncoder().encode(hotkeyChat) {
                defaults.set(data, forKey: Keys.hotkeyChat)
            }
        }
    }
    
    /// 翻译快捷键 (默认: T)
    @Published var hotkeyTranslate: HotkeyConfig {
        didSet {
            if let data = try? JSONEncoder().encode(hotkeyTranslate) {
                defaults.set(data, forKey: Keys.hotkeyTranslate)
            }
        }
    }
    
    /// 图像分析快捷键 (默认: L)
    @Published var hotkeyImage: HotkeyConfig {
        didSet {
            if let data = try? JSONEncoder().encode(hotkeyImage) {
                defaults.set(data, forKey: Keys.hotkeyImage)
            }
        }
    }
    
    /// 划词工具栏快捷键 (默认: S)
    @Published var hotkeySelection: HotkeyConfig {
        didSet {
            if let data = try? JSONEncoder().encode(hotkeySelection) {
                defaults.set(data, forKey: Keys.hotkeySelection)
            }
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
            self.translationLanguage = .chineseSimplified
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
        
        // 加载 Notion 配置
        self.notionEnabled = defaults.bool(forKey: Keys.notionEnabled)
        self.notionDatabaseId = defaults.string(forKey: Keys.notionDatabaseId) ?? ""
        self.todoListDatabaseId = defaults.string(forKey: Keys.todoListDatabaseId) ?? ""
        
        // 加载 Obsidian 配置
        self.obsidianEnabled = defaults.bool(forKey: Keys.obsidianEnabled)
        self.obsidianVaultPath = defaults.string(forKey: Keys.obsidianVaultPath) ?? ""
        self.obsidianChatLogFolder = defaults.string(forKey: Keys.obsidianChatLogFolder) ?? "ChatLogs"
        self.obsidianQuickSaveFolder = defaults.string(forKey: Keys.obsidianQuickSaveFolder) ?? "QuickNotes"
        
        // 加载划词助手配置（默认关闭）
        self.selectionAssistantEnabled = defaults.bool(forKey: Keys.selectionAssistantEnabled)
        
        // 加载快捷键配置
        self.hotkeyChat = Self.loadHotkeyConfig(from: defaults, key: Keys.hotkeyChat, default: .defaultChat)
        self.hotkeyTranslate = Self.loadHotkeyConfig(from: defaults, key: Keys.hotkeyTranslate, default: .defaultTranslate)
        self.hotkeyImage = Self.loadHotkeyConfig(from: defaults, key: Keys.hotkeyImage, default: .defaultImage)
        self.hotkeySelection = Self.loadHotkeyConfig(from: defaults, key: Keys.hotkeySelection, default: .defaultSelection)
        
        loadProviderConfigs()
    }
    
    /// 加载单个快捷键配置
    private static func loadHotkeyConfig(from defaults: UserDefaults, key: String, default defaultValue: HotkeyConfig) -> HotkeyConfig {
        if let data = defaults.data(forKey: key),
           let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            return config
        }
        return defaultValue
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
        translationLanguage = .chineseSimplified
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
