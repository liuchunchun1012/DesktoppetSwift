import Foundation
import Combine

/// AI 提供商管理器
/// 统一管理所有 AI 服务提供商的创建和切换
class AIProviderManager: ObservableObject {
    static let shared = AIProviderManager()
    
    // MARK: - Published Properties
    
    /// 当前激活的提供商
    @Published private(set) var currentProvider: AIProvider?
    
    /// 当前提供商类型
    @Published var currentProviderType: AIProviderType {
        didSet {
            UserSettings.shared.currentProvider = currentProviderType
            refreshCurrentProvider()
        }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    /// 聊天历史（所有提供商共享）
    private var chatHistory: [[String: String]] = []
    private let maxHistoryRounds = 20
    
    // MARK: - Initialization
    
    private init() {
        self.currentProviderType = UserSettings.shared.currentProvider
        refreshCurrentProvider()
        
        // 监听设置变化
        UserSettings.shared.$currentProvider
            .dropFirst()
            .sink { [weak self] newType in
                if self?.currentProviderType != newType {
                    self?.currentProviderType = newType
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 刷新当前提供商（配置变更后调用）
    func refreshCurrentProvider() {
        currentProvider = createProvider(for: currentProviderType)
        print("[AIProviderManager] Switched to \(currentProviderType.displayName)")
    }
    
    /// 创建指定类型的提供商
    func createProvider(for type: AIProviderType) -> AIProvider? {
        let config = UserSettings.shared.getConfig(for: type)
        
        switch type {
        case .ollama:
            return OllamaClient.shared
            
        case .openai, .qwen, .custom:
            return OpenAICompatibleClient(
                providerType: type,
                baseURL: config.baseURL,
                model: config.model
            )
            
        case .anthropic:
            return AnthropicClient(model: config.model)
            
        case .gemini:
            return GeminiClient(model: config.model)
        }
    }
    
    /// 检查当前提供商是否已配置
    var isCurrentProviderConfigured: Bool {
        return currentProvider?.isConfigured ?? false
    }
    
    /// 测试指定提供商的连接
    func testConnection(for type: AIProviderType, completion: @escaping (Bool) -> Void) {
        guard let provider = createProvider(for: type) else {
            completion(false)
            return
        }
        provider.checkHealth(completion: completion)
    }
    
    // MARK: - Chat Methods
    
    /// 发送聊天消息（流式）
    func chatStream(
        message: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        guard let provider = currentProvider else {
            onComplete(.failure(AIProviderError.notConfigured))
            return
        }
        
        // 添加用户消息到历史
        chatHistory.append(["role": "user", "content": message])
        trimHistory()
        
        // 构建系统提示词
        let systemPrompt = buildSystemPrompt()
        
        provider.chatStream(
            message: message,
            history: Array(chatHistory.dropLast()), // 不包含当前消息
            systemPrompt: systemPrompt,
            onUpdate: onUpdate,
            onComplete: { [weak self] result in
                // 添加助手回复到历史
                if case .success(let response) = result {
                    self?.chatHistory.append(["role": "assistant", "content": response])
                }
                onComplete(result)
            }
        )
    }
    
    /// 分析图片（流式）
    func analyzeImageStream(
        imageBase64: String,
        question: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        guard let provider = currentProvider else {
            onComplete(.failure(AIProviderError.notConfigured))
            return
        }
        
        // 添加到历史（带图片标记）
        let historyMessage = "[用户发送了一张图片] \(question)"
        chatHistory.append(["role": "user", "content": historyMessage])
        trimHistory()

        // 使用用户设置中的图片分析提示词，并替换占位符
        let systemPrompt = replacePlaceholders(in: UserSettings.shared.customImagePrompt)
        
        provider.analyzeImageStream(
            imageBase64: imageBase64,
            question: question,
            systemPrompt: systemPrompt,
            onUpdate: onUpdate,
            onComplete: { [weak self] result in
                if case .success(let response) = result {
                    self?.chatHistory.append(["role": "assistant", "content": response])
                }
                onComplete(result)
            }
        )
    }
    
    /// 翻译文本（流式）
    /// 注意：对于 Gemini，翻译使用更快的 flash 模型而非思考模型
    func translateStream(
        text: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        let targetLang = UserSettings.shared.translationLanguage.promptName
        let prompt = """
        Translate the following text to \(targetLang). Only output the translation, nothing else.
        
        Text: \(text)
        
        Translation:
        """
        
        // 为所有提供商创建优化的翻译客户端
        // 优化配置：关闭联网搜索、降低参数以提高速度
        let translationConfig = ProviderConfiguration(
            type: currentProviderType,
            enableWebSearch: false,      // 关闭联网搜索（翻译不需要）
            maxTokens: 2048,             // 降低输出长度（翻译通常不长）
            temperature: 0.3,            // 降低随机性（翻译需要确定性）
            topP: 0.9
        )

        // 根据不同提供商创建优化的临时客户端
        switch currentProviderType {
        case .gemini:
            // Gemini 使用快速 flash 模型
            if let apiKey = KeychainHelper.shared.getAPIKey(for: .gemini) {
                let fastClient = GeminiClient(apiKey: apiKey, model: "gemini-2.0-flash", config: translationConfig)
                fastClient.chatStream(
                    message: prompt,
                    history: [],
                    systemPrompt: "You are a professional translator.",
                    onUpdate: onUpdate,
                    onComplete: onComplete
                )
                return
            }

        case .anthropic:
            // Claude 使用 haiku 快速模型
            if let apiKey = KeychainHelper.shared.getAPIKey(for: .anthropic) {
                let fastClient = AnthropicClient(apiKey: apiKey, model: "claude-haiku-4.5-20251015", config: translationConfig)
                fastClient.chatStream(
                    message: prompt,
                    history: [],
                    systemPrompt: "You are a professional translator.",
                    onUpdate: onUpdate,
                    onComplete: onComplete
                )
                return
            }

        case .openai, .qwen, .custom:
            // OpenAI/Qwen/Custom 使用优化配置的客户端
            let currentConfig = UserSettings.shared.getConfig(for: currentProviderType)
            if let apiKey = KeychainHelper.shared.getAPIKey(for: currentProviderType) {
                let fastClient = OpenAICompatibleClient(
                    providerType: currentProviderType,
                    baseURL: currentConfig.baseURL,
                    apiKey: apiKey,
                    model: currentConfig.model,
                    config: translationConfig
                )
                fastClient.chatStream(
                    message: prompt,
                    history: [],
                    systemPrompt: "You are a professional translator.",
                    onUpdate: onUpdate,
                    onComplete: onComplete
                )
                return
            }

        case .ollama:
            // Ollama 使用当前提供商（本地模型，已经很快）
            break
        }

        // 备用方案：如果上面都没有返回，使用当前提供商
        guard let provider = currentProvider else {
            onComplete(.failure(AIProviderError.notConfigured))
            return
        }

        provider.chatStream(
            message: prompt,
            history: [],
            systemPrompt: "You are a professional translator.",
            onUpdate: onUpdate,
            onComplete: onComplete
        )
    }
    
    /// 清除聊天历史
    func clearChatHistory() {
        chatHistory.removeAll()
        print("[AIProviderManager] Chat history cleared")
    }
    
    /// 取消当前请求
    func cancelCurrentRequest() {
        currentProvider?.cancelCurrentRequest()
    }
    
    // MARK: - Private Methods
    
    private func buildSystemPrompt() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 EEEE HH:mm"
        let dateString = formatter.string(from: now)

        // 使用用户设置中的提示词，并替换占位符
        let basePrompt = replacePlaceholders(in: UserSettings.shared.customChatPrompt)

        return """
        【当前时间】\(dateString)

        \(basePrompt)
        """
    }

    /// 替换系统提示词中的占位符
    private func replacePlaceholders(in prompt: String) -> String {
        return prompt
            .replacingOccurrences(of: "{petName}", with: UserSettings.shared.petName)
            .replacingOccurrences(of: "{petNickname}", with: UserSettings.shared.petNickname)
            .replacingOccurrences(of: "{ownerName}", with: UserSettings.shared.ownerName)
    }
    
    private func trimHistory() {
        let maxMessages = maxHistoryRounds * 2
        if chatHistory.count > maxMessages {
            chatHistory = Array(chatHistory.suffix(maxMessages))
        }
    }
    
    // MARK: - Ollama Specific
    
    /// 获取已安装的 Ollama 模型列表
    func getInstalledOllamaModels(completion: @escaping ([String]) -> Void) {
        let url = URL(string: "\(PetConfig.ollamaBaseURL)/api/tags")!
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["models"] as? [[String: Any]] else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            let modelNames = models.compactMap { $0["name"] as? String }
            DispatchQueue.main.async {
                completion(modelNames)
            }
        }.resume()
    }
}
