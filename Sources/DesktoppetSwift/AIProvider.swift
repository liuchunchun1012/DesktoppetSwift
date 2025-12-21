import Foundation

// MARK: - AI Provider Types

/// AI 服务提供商类型
enum AIProviderType: String, Codable, CaseIterable, Identifiable {
    case ollama = "ollama"
    case openai = "openai"
    case anthropic = "anthropic"
    case gemini = "gemini"
    case qwen = "qwen"
    case custom = "custom"
    
    var id: String { rawValue }
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .ollama: return "Ollama (本地)"
        case .openai: return "OpenAI"
        case .anthropic: return "Claude (Anthropic)"
        case .gemini: return "Google Gemini"
        case .qwen: return "通义千问 (Qwen)"
        case .custom: return "自定义 (OpenAI 兼容)"
        }
    }
    
    /// 默认 Base URL
    var defaultBaseURL: String {
        switch self {
        case .ollama: return "http://localhost:11434"
        case .openai: return "https://api.openai.com"
        case .anthropic: return "https://api.anthropic.com"
        case .gemini: return "https://generativelanguage.googleapis.com"
        case .qwen: return "https://dashscope.aliyuncs.com/compatible-mode"
        case .custom: return ""
        }
    }
    
    /// 推荐模型列表 (2025年12月最新)
    var recommendedModels: [String] {
        switch self {
        case .ollama:
            return ["gemma3:4b-it-qat", "gemma3:12b-it-qat", "qwen3:4b", "llava:7b"]
        case .openai:
            // GPT-5.2 系列是最新的
            return ["gpt-5.2-instant", "gpt-5.2-thinking", "gpt-5-mini", "gpt-4o", "gpt-4o-mini"]
        case .anthropic:
            // Claude 4.5 系列是最新的
            return ["claude-opus-4.5-20251124", "claude-sonnet-4.5-20250929", "claude-haiku-4.5-20251015", "claude-sonnet-4-20250522"]
        case .gemini:
            // Gemini 3 系列 API 模型 ID 带 -preview 后缀
            return ["gemini-3-pro-preview", "gemini-3-flash-preview", "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash"]
        case .qwen:
            // Qwen 最新模型列表
            return ["qwen3-max", "qwen3-vl-plus", "qwen-vl-max", "qwen-plus"]
        case .custom:
            // API2D 联网功能兼容的模型（优先推荐）
            // Claude 系列不支持 API2D 联网，但可正常对话
            return [
                "gpt-4o",           // ✅ 支持联网
                "gpt-4o-mini",      // ✅ 支持联网
                "claude-3-5-sonnet-latest",  // ❌ 不支持联网
                "claude-haiku-4-5", // ❌ 不支持联网
                "gemini-2.5-flash", // 🤔 待测试
                "deepseek-chat"     // 普通对话
            ]
        }
    }
    
    /// 默认模型
    var defaultModel: String {
        recommendedModels.first ?? ""
    }
    
    /// 是否需要 API Key
    var requiresAPIKey: Bool {
        switch self {
        case .ollama: return false
        default: return true
        }
    }
    
    /// 是否支持视觉
    var supportsVision: Bool {
        switch self {
        case .ollama: return true  // 取决于模型
        case .openai: return true
        case .anthropic: return true
        case .gemini: return true
        case .qwen: return true  // qwen-vl 系列支持
        case .custom: return true  // 假设支持
        }
    }
}

// MARK: - Translation Language

/// 翻译目标语言
enum TranslationLanguage: String, Codable, CaseIterable, Identifiable {
    case chinese = "zh"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    
    var id: String { rawValue }
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }
    
    /// 翻译提示词中使用的语言名
    var promptName: String {
        switch self {
        case .chinese: return "Chinese"
        case .english: return "English"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        }
    }
}

// MARK: - AI Provider Protocol

/// AI 服务提供商协议
/// 所有 AI 客户端必须实现此协议
protocol AIProvider: AnyObject {
    /// 提供商类型
    var providerType: AIProviderType { get }
    
    /// 当前模型
    var currentModel: String { get set }
    
    /// 是否已正确配置
    var isConfigured: Bool { get }
    
    /// 流式聊天
    /// - Parameters:
    ///   - message: 用户消息
    ///   - history: 聊天历史
    ///   - systemPrompt: 系统提示词
    ///   - onUpdate: 每次收到新 token 时的回调
    ///   - onComplete: 完成时的回调
    func chatStream(
        message: String,
        history: [[String: String]],
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    )
    
    /// 流式图片分析
    /// - Parameters:
    ///   - imageBase64: Base64 编码的图片
    ///   - question: 用户问题
    ///   - systemPrompt: 系统提示词
    ///   - onUpdate: 每次收到新 token 时的回调
    ///   - onComplete: 完成时的回调
    func analyzeImageStream(
        imageBase64: String,
        question: String,
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    )
    
    /// 检查服务健康状态
    func checkHealth(completion: @escaping (Bool) -> Void)
    
    /// 取消当前请求
    func cancelCurrentRequest()
}

// MARK: - Provider Configuration

/// AI 提供商配置
struct ProviderConfiguration: Codable, Identifiable {
    var id: String { type.rawValue }
    var type: AIProviderType
    var baseURL: String
    var model: String
    var isEnabled: Bool
    
    // 生成参数
    var enableWebSearch: Bool
    var maxTokens: Int
    var temperature: Double
    var topP: Double

    init(
        type: AIProviderType,
        baseURL: String? = nil,
        model: String? = nil,
        isEnabled: Bool = true,
        enableWebSearch: Bool = true,
        maxTokens: Int? = nil,
        temperature: Double = 1.0,
        topP: Double = 0.95
    ) {
        self.type = type
        self.baseURL = baseURL ?? type.defaultBaseURL
        self.model = model ?? type.defaultModel
        self.isEnabled = isEnabled
        self.enableWebSearch = enableWebSearch
        // 默认 max_tokens 根据提供商不同
        self.maxTokens = maxTokens ?? type.defaultMaxTokens
        self.temperature = temperature
        self.topP = topP
    }
}

extension AIProviderType {
    /// 默认 max_tokens
    var defaultMaxTokens: Int {
        switch self {
        case .ollama: return 4096
        case .openai: return 8192
        case .anthropic: return 16384
        case .gemini: return 65536
        case .qwen: return 8192
        case .custom: return 8192
        }
    }
}

// MARK: - AI Provider Error

/// AI 提供商错误
enum AIProviderError: Error, LocalizedError {
    case notConfigured
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case rateLimited
    case modelNotFound
    case serverError(String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI 服务未配置，请在设置中配置 API Key"
        case .invalidAPIKey:
            return "API Key 无效"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "服务器返回了无效的响应"
        case .rateLimited:
            return "请求过于频繁，请稍后再试"
        case .modelNotFound:
            return "模型不存在"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .cancelled:
            return "请求已取消"
        }
    }
}

// MARK: - Default Implementation Helpers

extension AIProvider {
    /// 过滤模型输出中的特殊标记
    func cleanModelOutput(_ text: String) -> String {
        var cleaned = text
        let artifactsToRemove = [
            "<end_of_turn>", "end of turn",
            "<start_of_turn>", "start of turn",
            "<|eot_id|>", "<|end|>", "<|start|>",
            "<|im_end|>", "<|im_start|>",
            "model", "assistant"
        ]
        for artifact in artifactsToRemove {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "", options: .caseInsensitive)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
