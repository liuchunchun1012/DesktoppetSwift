import Foundation

/// Anthropic Claude API 客户端
class AnthropicClient: NSObject, AIProvider, URLSessionDataDelegate {
    
    // MARK: - Properties

    let providerType: AIProviderType = .anthropic
    var currentModel: String

    private let baseURL = "https://api.anthropic.com"
    private let apiKey: String
    private let apiVersion = "2023-06-01"
    private var config: ProviderConfiguration

    private var streamSession: URLSession?
    private var fullResponse = ""
    private var onStreamUpdate: ((String) -> Void)?
    private var onStreamComplete: ((Result<String, Error>) -> Void)?

    // MARK: - Initialization

    init(apiKey: String, model: String = "claude-3-5-sonnet-20241022", config: ProviderConfiguration? = nil) {
        self.apiKey = apiKey
        self.currentModel = model
        self.config = config ?? UserSettings.shared.getConfig(for: .anthropic)
        super.init()
    }

    /// 便捷初始化：从 Keychain 读取 API Key
    convenience init?(model: String? = nil) {
        guard let apiKey = KeychainHelper.shared.getAPIKey(for: .anthropic), !apiKey.isEmpty else {
            return nil
        }
        let config = UserSettings.shared.getConfig(for: .anthropic)
        self.init(apiKey: apiKey, model: model ?? config.model, config: config)
    }
    
    // MARK: - AIProvider Protocol
    
    var isConfigured: Bool {
        return !apiKey.isEmpty && !currentModel.isEmpty
    }
    
    func chatStream(
        message: String,
        history: [[String: String]],
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        // 构建消息数组（Anthropic 格式）
        var messages: [[String: Any]] = []
        
        // 添加历史消息
        for msg in history {
            if let role = msg["role"], let content = msg["content"] {
                // Anthropic 只支持 user 和 assistant
                let anthropicRole = role == "user" ? "user" : "assistant"
                messages.append(["role": anthropicRole, "content": content])
            }
        }
        
        // 添加当前消息
        messages.append(["role": "user", "content": message])
        
        sendStreamRequest(
            messages: messages,
            systemPrompt: systemPrompt,
            onUpdate: onUpdate,
            onComplete: onComplete
        )
    }
    
    func analyzeImageStream(
        imageBase64: String,
        question: String,
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        // Anthropic 图片格式
        let userContent: [[String: Any]] = [
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/png",
                    "data": imageBase64
                ]
            ],
            ["type": "text", "text": question]
        ]
        
        let messages: [[String: Any]] = [
            ["role": "user", "content": userContent]
        ]
        
        sendStreamRequest(
            messages: messages,
            systemPrompt: systemPrompt,
            onUpdate: onUpdate,
            onComplete: onComplete
        )
    }
    
    func checkHealth(completion: @escaping (Bool) -> Void) {
        // Anthropic 没有专门的模型列表端点，发送一个简单请求验证模型
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        let body: [String: Any] = [
            "model": currentModel,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // 成功：模型存在并可用
                    print("[AnthropicClient] Model '\(self.currentModel)' verified")
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } else if let data = data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let error = json["error"] as? [String: Any],
                          let errorType = error["type"] as? String {
                    // 检查是否是模型不存在的错误
                    if errorType == "invalid_request_error" {
                        let message = error["message"] as? String ?? ""
                        if message.contains("model") {
                            print("[AnthropicClient] Model '\(self.currentModel)' NOT FOUND: \(message)")
                            DispatchQueue.main.async {
                                completion(false)
                            }
                            return
                        }
                    }
                    // 其他错误（如 token 用完等）但模型有效
                    print("[AnthropicClient] API returned error but model likely valid: \(errorType)")
                    DispatchQueue.main.async {
                        completion(httpResponse.statusCode < 500)
                    }
                } else {
                    print("[AnthropicClient] API Error: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        completion(httpResponse.statusCode < 500)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    func cancelCurrentRequest() {
        streamSession?.invalidateAndCancel()
        streamSession = nil
        onStreamComplete?(.failure(AIProviderError.cancelled))
        onStreamComplete = nil
        onStreamUpdate = nil
    }
    
    // MARK: - Private Methods
    
    private func sendStreamRequest(
        messages: [[String: Any]],
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            onComplete(.failure(AIProviderError.invalidResponse))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        
        // 配置生成参数（使用用户设置）
        var body: [String: Any] = [
            "model": currentModel,
            "max_tokens": config.maxTokens,
            "system": systemPrompt,
            "messages": messages,
            "stream": true,
            "temperature": config.temperature,
            "top_p": config.topP,
            "top_k": 0  // 0 表示不使用 top_k
        ]

        // 添加 web_search tool 启用联网功能（如果启用）
        if config.enableWebSearch {
            body["tools"] = [
                ["type": "web_search", "max_uses": 3]
            ]
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            onComplete(.failure(error))
            return
        }
        
        self.onStreamUpdate = onUpdate
        self.onStreamComplete = onComplete
        self.fullResponse = ""
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        streamSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        let task = streamSession?.dataTask(with: request)
        task?.resume()
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        
        let lines = chunk.components(separatedBy: "\n")
        for line in lines {
            guard line.hasPrefix("data: ") else { continue }
            
            let jsonString = String(line.dropFirst(6))
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }
            
            // Anthropic 流式格式：content_block_delta
            if let type = json["type"] as? String,
               type == "content_block_delta",
               let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                fullResponse += text
                DispatchQueue.main.async {
                    self.onStreamUpdate?(self.fullResponse)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.onStreamComplete?(.failure(AIProviderError.networkError(error)))
            }
        } else {
            let cleaned = cleanModelOutput(fullResponse)
            DispatchQueue.main.async {
                self.onStreamComplete?(.success(cleaned))
            }
        }
        
        streamSession?.invalidateAndCancel()
        streamSession = nil
    }
}
