import Foundation

/// OpenAI 兼容 API 客户端
/// 支持 OpenAI、Qwen、DeepSeek、Moonshot、中转 API 等
class OpenAICompatibleClient: NSObject, AIProvider, URLSessionDataDelegate {
    
    // MARK: - Properties

    let providerType: AIProviderType
    var currentModel: String

    private let baseURL: String
    private let apiKey: String
    private var config: ProviderConfiguration

    private var streamSession: URLSession?
    private var receiveBuffer = Data() // 用于存储未处理的流式数据
    private var fullResponse = ""
    private var onStreamUpdate: ((String) -> Void)?
    private var onStreamComplete: ((Result<String, Error>) -> Void)?

    // MARK: - Initialization

    init(providerType: AIProviderType, baseURL: String, apiKey: String, model: String, config: ProviderConfiguration? = nil) {
        self.providerType = providerType
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiKey = apiKey
        self.currentModel = model
        self.config = config ?? UserSettings.shared.getConfig(for: providerType)
        super.init()
    }

    /// 便捷初始化：从 Keychain 读取 API Key
    convenience init?(providerType: AIProviderType, baseURL: String? = nil, model: String? = nil) {
        guard let apiKey = KeychainHelper.shared.getAPIKey(for: providerType), !apiKey.isEmpty else {
            return nil
        }

        let config = UserSettings.shared.getConfig(for: providerType)
        let url = baseURL ?? config.baseURL
        let modelName = model ?? config.model

        self.init(providerType: providerType, baseURL: url, apiKey: apiKey, model: modelName, config: config)
    }
    
    // MARK: - AIProvider Protocol
    
    var isConfigured: Bool {
        return !apiKey.isEmpty && !baseURL.isEmpty && !currentModel.isEmpty
    }
    
    func chatStream(
        message: String,
        history: [[String: String]],
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        // 构建消息数组
        var messages: [[String: Any]] = []
        
        // 恢复标准 System Prompt 模式
        let trimmedSystem = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSystem.isEmpty {
            messages.append(["role": "system", "content": trimmedSystem])
        }
        
        // 添加历史消息
        // 【兼容性修复】过滤掉 function/tool 角色的消息
        // API2D 联网会产生 function 消息，但切换模型后可能不兼容
        let allowedRoles = ["system", "user", "assistant"]
        for msg in history {
            if let role = msg["role"], let content = msg["content"] {
                if allowedRoles.contains(role) {
                    messages.append(["role": role, "content": content])
                }
                // 跳过 function/tool 等其他角色
            }
        }
        
        // 添加当前消息
        // 【API2D 联网】如果开启了联网功能且是自定义模式，在消息前添加触发关键词
        // 注意：Claude 不支持 API2D 的联网功能（因为它使用 function_call 格式）
        var finalMessage = message
        let isClaude = currentModel.lowercased().contains("claude")
        if providerType == .custom && config.enableWebSearch && !isClaude {
            // 触发关键词，用户需要在 API2D 后台设置相同的关键词
            finalMessage = "@联网 " + message
        }
        messages.append(["role": "user", "content": finalMessage])
        
        // 发送请求
        sendStreamRequest(messages: messages, onUpdate: onUpdate, onComplete: onComplete)
    }
    
    func analyzeImageStream(
        imageBase64: String,
        question: String,
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        // 构建带图片的消息
        let userContent: [[String: Any]] = [
            ["type": "text", "text": question],
            [
                "type": "image_url",
                "image_url": ["url": "data:image/png;base64,\(imageBase64)"]
            ]
        ]
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userContent]
        ]
        
        sendStreamRequest(messages: messages, onUpdate: onUpdate, onComplete: onComplete)
    }
    
    func checkHealth(completion: @escaping (Bool) -> Void) {
        // 方案 1: 尝试获取模型列表
        guard let modelsUrl = URL(string: "\(baseURL)/v1/models") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: modelsUrl)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // 成功获取模型列表
                DispatchQueue.main.async {
                    completion(true)
                }
                return
            }
            
            // 方案 2: 如果模型列表失败（某些中转不支持），尝试发送一个空的 Chat 请求来验证 Key
            print("[OpenAIClient] /v1/models failed, trying dry-run chat request...")
            self.performDryRunChat(completion: completion)
            
        }.resume()
    }
    
    private func performDryRunChat(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 发送一个极简请求
        let body: [String: Any] = [
            "model": currentModel,
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 1
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                // 只要状态码由 200 (OK) 或 400 (Bad Request - 可能是参数问题但证明连通) 
                // 或 429 (Rate Limit) 算连接成功，主要是验证网络连通性和 API Key
                // 401 (Unauthorized) 肯定是失败
                let isSuccess = (200...299).contains(httpResponse.statusCode)
                print("[OpenAIClient] Dry run status: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(isSuccess)
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
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        let isAPI2DClaude = baseURL.contains("api2d") && currentModel.lowercased().contains("claude")
        
        // 如果是 API2D 的 Claude，尝试使用原生路径以获得更好稳定性
        var finalURLString = "\(baseURL)/v1/chat/completions"
        if isAPI2DClaude && !baseURL.contains("/claude") {
            // 如果用户填的是 https://oa.api2d.net，我们补全路径
            // 或者兼容它已经填了 https://oa.api2d.net/claude 的情况
            // 注意：这里取决于 API2D 后端的具体转发逻辑
        }
        
        guard let url = URL(string: finalURLString) else {
            onComplete(.failure(AIProviderError.invalidResponse))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 核心参数
        var body: [String: Any] = [
            "model": currentModel,
            "stream": true
        ]
        
        // 只有非自定义模式下才发送这些生成参数
        if providerType != .custom {
            if config.maxTokens > 0 {
                body["max_tokens"] = config.maxTokens
            }
            if config.temperature != 1.0 {
                body["temperature"] = config.temperature
            }
            // 联网功能
            if config.enableWebSearch {
                if providerType == .openai {
                    body["tools"] = [["type": "web_search"]]
                } else if providerType == .qwen {
                    body["enable_search"] = true
                }
            }
        } else {
            // 【自定义模式/API2D】
            // 注意：API2D 的联网功能通过关键词触发，已在 chatStream 中处理
            // 这里不再发送任何 tools 参数
            let isClaude = currentModel.lowercased().contains("claude")
            
            if isClaude {
                // 针对 Claude 强行补全 max_tokens，避免余额冻结失败
                body["max_tokens"] = config.maxTokens > 0 ? config.maxTokens : 4096
            }
        }
        
        // 【核心修复】深度协议适配
        if currentModel.lowercased().contains("claude") {
            // Claude 原生/高级中转协议中，system 是顶层字段，messages 只能包含 user/assistant
            var systemText = ""
            var filteredMessages: [[String: Any]] = []
            
            for msg in messages {
                if let role = msg["role"] as? String, role == "system" {
                    systemText += (msg["content"] as? String ?? "") + "\n"
                } else {
                    // 极致洗白：强制 role/content 为 String
                    guard let role = msg["role"] as? String else { continue }
                    let contentStr = (msg["content"] as? String) ?? ""
                    filteredMessages.append(["role": role, "content": contentStr])
                }
            }
            
            if !systemText.isEmpty {
                body["system"] = systemText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            body["messages"] = filteredMessages
            
            // Claude 必须指定 max_tokens
            if body["max_tokens"] == nil {
                body["max_tokens"] = config.maxTokens > 0 ? config.maxTokens : 4096
            }
        } else {
            // 标准 OpenAI 模式：保持消息在 messages 数组中
            let cleanedMessages: [[String: Any]] = messages.compactMap { msg in
                guard let role = msg["role"] as? String else { return nil }
                let contentStr = (msg["content"] as? String) ?? ""
                return ["role": role, "content": contentStr]
            }
            body["messages"] = cleanedMessages
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            onComplete(.failure(error))
            return
        }
        
        // 存储回调
        self.onStreamUpdate = onUpdate
        self.onStreamComplete = onComplete
        self.fullResponse = ""
        self.receiveBuffer = Data()
        
        print("[OpenAIClient] Sending request to \(url)")
        
        // 创建流式会话
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60 
        streamSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: .main)
        
        let task = streamSession?.dataTask(with: request)
        task?.resume()
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receiveBuffer.append(data)
        
        // 尝试从缓冲区中提取完整的行
        while let newlineIndex = receiveBuffer.firstIndex(of: 10) { // 10 is '\n'
            let lineData = receiveBuffer.prefix(upTo: newlineIndex)
            receiveBuffer.removeSubrange(...newlineIndex)
            
            guard let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }
            
            // 只打印异常或关键行，正常的数据流日志不在这里打，减少刷屏
            if line.contains("\"error\"") || (!line.hasPrefix("data: ") && line.contains("{")) {
                print("[OpenAIClient] Important: \(line)")
            }
            
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                if jsonString == "[DONE]" { 
                    print("[OpenAIClient] Stream [DONE]")
                    continue 
                }
                processJSON(jsonString)
            } else if line.contains("\"choices\"") || line.contains("\"delta\"") || line.contains("\"content\"") {
                processJSON(line)
            }
        }
    }
    
    private func processJSON(_ jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else { return }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return }
            
            // 错误检测优先
            if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                print("[OpenAIClient] SERVER ERROR: \(message)")
                DispatchQueue.main.async {
                    self.onStreamComplete?(.failure(NSError(domain: "AIProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: message])))
                    self.onStreamComplete = nil
                }
                return
            }
            
            var contentFound = false
            
            // 1. 标准 OpenAI
            if let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let delta = firstChoice["delta"] as? [String: Any] {
                if let content = delta["content"] as? String {
                    fullResponse += content
                    contentFound = true
                } else if let text = delta["text"] as? String {
                    fullResponse += text
                    contentFound = true
                }
            }
            // 2. Anthropic / API2D 透传格式
            else if let type = json["type"] as? String, type == "content_block_delta",
                    let delta = json["delta"] as? [String: Any] {
                if let text = delta["text"] as? String {
                    fullResponse += text
                    contentFound = true
                }
            }
            // 3. 兼容顶层 delta.text
            else if let delta = json["delta"] as? [String: Any], let text = delta["text"] as? String {
                fullResponse += text
                contentFound = true
            }
            
            if contentFound {
                DispatchQueue.main.async {
                    self.onStreamUpdate?(self.fullResponse)
                }
            }
        } catch {
            // 解析失败不报错，可能是半截 JSON
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("[OpenAIClient] Request failed: \(error)")
            DispatchQueue.main.async {
                self.onStreamComplete?(.failure(error))
            }
        } else {
            // 最后的状态检查
            if let httpResponse = task.response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let rawBody = String(data: receiveBuffer, encoding: .utf8) ?? "None"
                print("[OpenAIClient] HTTP ERROR \(httpResponse.statusCode). Raw Body: \(rawBody)")
                
                // 尝试从 Body 里提取错误消息
                DispatchQueue.main.async {
                    if self.onStreamComplete != nil {
                        self.onStreamComplete?(.failure(NSError(domain: "AIProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(rawBody)"])))
                    }
                }
            } else {
                print("[OpenAIClient] Request completed successfully.")
                let cleaned = cleanModelOutput(fullResponse)
                DispatchQueue.main.async {
                    self.onStreamComplete?(.success(cleaned))
                }
            }
        }
        
        // 清理状态
        streamSession?.invalidateAndCancel()
        streamSession = nil
        receiveBuffer = Data()
        onStreamComplete = nil
        onStreamUpdate = nil
    }
}
