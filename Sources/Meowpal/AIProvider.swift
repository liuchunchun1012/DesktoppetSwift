import Foundation

// MARK: - AI Provider Types

/// AI provider types
enum AIProviderType: String, Codable, CaseIterable, Identifiable {
    case ollama = "ollama"
    case openai = "openai"
    case anthropic = "anthropic"
    case gemini = "gemini"
    case grok = "grok"
    case qwen = "qwen"
    case deepseek = "deepseek"
    case custom = "custom"
    
    var id: String { rawValue }
    
    /// Display name
    var displayName: String {
        switch self {
        case .ollama: return "Ollama (Local)"
        case .openai: return "OpenAI"
        case .anthropic: return "Claude (Anthropic)"
        case .gemini: return "Google Gemini"
        case .grok: return "xAI Grok"
        case .qwen: return "Qwen (Tongyi)"
        case .deepseek: return "DeepSeek"
        case .custom: return "Custom (OpenAI Compatible)"
        }
    }
    
    /// Default Base URL
    var defaultBaseURL: String {
        switch self {
        case .ollama: return "http://localhost:11434"
        case .openai: return "https://api.openai.com"
        case .anthropic: return "https://api.anthropic.com"
        case .gemini: return "https://generativelanguage.googleapis.com"
        case .grok: return "https://api.x.ai"
        case .qwen: return "https://dashscope.aliyuncs.com/compatible-mode"
        case .deepseek: return "https://api.deepseek.com"
        case .custom: return ""
        }
    }
    
    /// Recommended models
    var recommendedModels: [String] {
        switch self {
        case .ollama:
            return ["gemma3:4b-it-qat", "gemma3:12b-it-qat", "qwen3:4b", "llava:7b"]
        case .openai:
            return ["gpt-5.2-instant", "gpt-5.2-thinking", "gpt-5-mini", "gpt-4o", "gpt-4o-mini"]
        case .anthropic:
            return ["claude-opus-4.5-20251124", "claude-sonnet-4.5-20250929", "claude-haiku-4.5-20251015", "claude-sonnet-4-20250522"]
        case .gemini:
            return ["gemini-3-pro-preview", "gemini-3-flash-preview", "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash"]
        case .grok:
            return ["grok-3", "grok-3-fast", "grok-3-mini", "grok-3-mini-fast", "grok-2-vision"]
        case .qwen:
            return ["qwen3-max", "qwen3-vl-plus", "qwen-vl-max", "qwen-plus"]
        case .deepseek:
            return ["deepseek-v4-flash", "deepseek-v4-pro", "deepseek-chat", "deepseek-reasoner"]
        case .custom:
            return [
                "gpt-4o",
                "gpt-4o-mini",
                "claude-3-5-sonnet-latest",
                "claude-haiku-4-5",
                "gemini-2.5-flash",
                "deepseek-chat"
            ]
        }
    }
    
    /// Default model
    var defaultModel: String {
        recommendedModels.first ?? ""
    }
    
    /// Requires API Key
    var requiresAPIKey: Bool {
        switch self {
        case .ollama: return false
        default: return true
        }
    }
    
    /// Supports vision
    var supportsVision: Bool {
        switch self {
        case .ollama: return true
        case .openai: return true
        case .anthropic: return true
        case .gemini: return true
        case .grok: return true  // grok-2-vision supports images
        case .qwen: return true
        case .deepseek: return false
        case .custom: return true
        }
    }
}

// MARK: - Translation Language

/// Translation target language (ordered by global popularity)
enum TranslationLanguage: String, Codable, CaseIterable, Identifiable {
    // Top tier - most spoken
    case english = "en"
    case chineseSimplified = "zh-CN"
    case chineseTraditional = "zh-TW"
    case spanish = "es"
    case hindi = "hi"
    case arabic = "ar"
    case portuguese = "pt"
    case bengali = "bn"
    case russian = "ru"
    case japanese = "ja"
    
    // Second tier - major languages
    case german = "de"
    case french = "fr"
    case korean = "ko"
    case italian = "it"
    case vietnamese = "vi"
    case turkish = "tr"
    case persian = "fa"
    case urdu = "ur"
    case thai = "th"
    case indonesian = "id"
    
    // Third tier - regional languages
    case polish = "pl"
    case ukrainian = "uk"
    case dutch = "nl"
    case malay = "ms"
    case tagalog = "tl"
    case romanian = "ro"
    case greek = "el"
    case czech = "cs"
    case hungarian = "hu"
    case swedish = "sv"
    
    // Fourth tier - smaller but significant
    case hebrew = "he"
    case danish = "da"
    case finnish = "fi"
    case norwegian = "no"
    case swahili = "sw"
    case catalan = "ca"
    case slovak = "sk"
    case croatian = "hr"
    case serbian = "sr"
    case bulgarian = "bg"
    
    var id: String { rawValue }
    
    /// Display name (native name)
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .spanish: return "Español"
        case .hindi: return "हिन्दी"
        case .arabic: return "العربية"
        case .portuguese: return "Português"
        case .bengali: return "বাংলা"
        case .russian: return "Русский"
        case .japanese: return "日本語"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .korean: return "한국어"
        case .italian: return "Italiano"
        case .vietnamese: return "Tiếng Việt"
        case .turkish: return "Türkçe"
        case .persian: return "فارسی"
        case .urdu: return "اردو"
        case .thai: return "ไทย"
        case .indonesian: return "Bahasa Indonesia"
        case .polish: return "Polski"
        case .ukrainian: return "Українська"
        case .dutch: return "Nederlands"
        case .malay: return "Bahasa Melayu"
        case .tagalog: return "Tagalog"
        case .romanian: return "Română"
        case .greek: return "Ελληνικά"
        case .czech: return "Čeština"
        case .hungarian: return "Magyar"
        case .swedish: return "Svenska"
        case .hebrew: return "עברית"
        case .danish: return "Dansk"
        case .finnish: return "Suomi"
        case .norwegian: return "Norsk"
        case .swahili: return "Kiswahili"
        case .catalan: return "Català"
        case .slovak: return "Slovenčina"
        case .croatian: return "Hrvatski"
        case .serbian: return "Српски"
        case .bulgarian: return "Български"
        }
    }
    
    /// Language name for use in AI prompts
    var promptName: String {
        switch self {
        case .english: return "English"
        case .chineseSimplified: return "Simplified Chinese"
        case .chineseTraditional: return "Traditional Chinese"
        case .spanish: return "Spanish"
        case .hindi: return "Hindi"
        case .arabic: return "Arabic"
        case .portuguese: return "Portuguese"
        case .bengali: return "Bengali"
        case .russian: return "Russian"
        case .japanese: return "Japanese"
        case .german: return "German"
        case .french: return "French"
        case .korean: return "Korean"
        case .italian: return "Italian"
        case .vietnamese: return "Vietnamese"
        case .turkish: return "Turkish"
        case .persian: return "Persian"
        case .urdu: return "Urdu"
        case .thai: return "Thai"
        case .indonesian: return "Indonesian"
        case .polish: return "Polish"
        case .ukrainian: return "Ukrainian"
        case .dutch: return "Dutch"
        case .malay: return "Malay"
        case .tagalog: return "Filipino/Tagalog"
        case .romanian: return "Romanian"
        case .greek: return "Greek"
        case .czech: return "Czech"
        case .hungarian: return "Hungarian"
        case .swedish: return "Swedish"
        case .hebrew: return "Hebrew"
        case .danish: return "Danish"
        case .finnish: return "Finnish"
        case .norwegian: return "Norwegian"
        case .swahili: return "Swahili"
        case .catalan: return "Catalan"
        case .slovak: return "Slovak"
        case .croatian: return "Croatian"
        case .serbian: return "Serbian"
        case .bulgarian: return "Bulgarian"
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
    /// Default max_tokens
    var defaultMaxTokens: Int {
        switch self {
        case .ollama: return 4096
        case .openai: return 8192
        case .anthropic: return 16384
        case .gemini: return 65536
        case .grok: return 8192
        case .qwen: return 8192
        case .deepseek: return 8192
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
            return "AI not configured. Please set up API Key in Settings"
        case .invalidAPIKey:
            return "Invalid API Key"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Server returned invalid response"
        case .rateLimited:
            return "Rate limited. Please try again later"
        case .modelNotFound:
            return "Model not found"
        case .serverError(let message):
            return "Server Error: \(message)"
        case .cancelled:
            return "Request cancelled"
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
