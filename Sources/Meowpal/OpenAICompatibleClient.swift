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
    private var httpStatusCode: Int = 0

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
        let modelsPath = providerType == .deepseek ? "/models" : "/v1/models"
        guard let modelsUrl = URL(string: "\(baseURL)\(modelsPath)") else {
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
            print("[OpenAIClient] models endpoint failed, trying dry-run chat request...")
            self.performDryRunChat(completion: completion)
            
        }.resume()
    }
    
    private func performDryRunChat(completion: @escaping (Bool) -> Void) {
        let chatPath = providerType == .deepseek ? "/chat/completions" : "/v1/chat/completions"
        guard let url = URL(string: "\(baseURL)\(chatPath)") else {
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
        if providerType == .deepseek && config.enableWebSearch {
            sendDeepSeekToolRequest(messages: messages, onUpdate: onUpdate, onComplete: onComplete)
            return
        }
        
        let isAPI2DClaude = baseURL.contains("api2d") && currentModel.lowercased().contains("claude")
        
        // 如果是 API2D 的 Claude，尝试使用原生路径以获得更好稳定性
        let finalURLString = providerType == .deepseek ? "\(baseURL)/chat/completions" : "\(baseURL)/v1/chat/completions"
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
                var cleaned: [String: Any] = ["role": role]
                cleaned["content"] = msg["content"] ?? ""
                if let toolCallID = msg["tool_call_id"] {
                    cleaned["tool_call_id"] = toolCallID
                }
                if let toolCalls = msg["tool_calls"] {
                    cleaned["tool_calls"] = toolCalls
                }
                return cleaned
            }
            body["messages"] = cleanedMessages
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
        self.receiveBuffer = Data()
        self.httpStatusCode = 0
        
        print("[OpenAIClient] Sending request to \(url)")
        
        // 创建流式会话
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60 
        streamSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: .main)
        
        let task = streamSession?.dataTask(with: request)
        task?.resume()
    }
    
    private struct DeepSeekToolCall {
        let id: String
        let name: String
        let arguments: String
    }
    
    private func sendDeepSeekToolRequest(
        messages: [[String: Any]],
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            onComplete(.failure(AIProviderError.invalidResponse))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "model": currentModel,
            "messages": messages,
            "stream": false,
            "tools": [deepSeekWebSearchTool()],
            "tool_choice": "auto"
        ]
        if config.maxTokens > 0 {
            body["max_tokens"] = config.maxTokens
        }
        if config.temperature != 1.0 {
            body["temperature"] = config.temperature
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            onComplete(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { onComplete(.failure(error)) }
                return
            }
            
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                DispatchQueue.main.async {
                    onComplete(.failure(NSError(domain: "AIProvider", code: status, userInfo: [NSLocalizedDescriptionKey: "HTTP \(status): \(body)"])))
                }
                return
            }
            
            self.handleDeepSeekToolResponse(data: data, originalMessages: messages, onUpdate: onUpdate, onComplete: onComplete)
        }.resume()
    }
    
    private func deepSeekWebSearchTool() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "web_search",
                "description": "Search the web for current information and return concise results with source URLs.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "The web search query."
                        ],
                        "count": [
                            "type": "integer",
                            "description": "The number of search results to return.",
                            "minimum": 1,
                            "maximum": 10
                        ]
                    ],
                    "required": ["query"]
                ]
            ]
        ]
    }
    
    private func handleDeepSeekToolResponse(
        data: Data,
        originalMessages: [[String: Any]],
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any] else {
                DispatchQueue.main.async { onComplete(.failure(AIProviderError.invalidResponse)) }
                return
            }
            
            let toolCalls = parseDeepSeekToolCalls(from: message)
            guard !toolCalls.isEmpty else {
                if let content = message["content"] as? String, !content.isEmpty {
                    DispatchQueue.main.async {
                        onUpdate(content)
                        onComplete(.success(self.cleanModelOutput(content)))
                    }
                } else {
                    DispatchQueue.main.async { onComplete(.failure(AIProviderError.invalidResponse)) }
                }
                return
            }
            
            executeDeepSeekToolCall(toolCalls[0], originalMessages: originalMessages, assistantMessage: message, onUpdate: onUpdate, onComplete: onComplete)
        } catch {
            DispatchQueue.main.async { onComplete(.failure(error)) }
        }
    }
    
    private func parseDeepSeekToolCalls(from message: [String: Any]) -> [DeepSeekToolCall] {
        guard let rawToolCalls = message["tool_calls"] as? [[String: Any]] else {
            return []
        }
        
        return rawToolCalls.compactMap { raw in
            guard let id = raw["id"] as? String,
                  let function = raw["function"] as? [String: Any],
                  let name = function["name"] as? String else {
                return nil
            }
            let arguments = function["arguments"] as? String ?? "{}"
            return DeepSeekToolCall(id: id, name: name, arguments: arguments)
        }
    }
    
    private func executeDeepSeekToolCall(
        _ toolCall: DeepSeekToolCall,
        originalMessages: [[String: Any]],
        assistantMessage: [String: Any],
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        guard toolCall.name == "web_search" else {
            DispatchQueue.main.async {
                onComplete(.failure(AIProviderError.serverError("Unsupported DeepSeek tool call: \(toolCall.name)")))
            }
            return
        }
        
        let query = parseWebSearchQuery(arguments: toolCall.arguments)
        guard !query.isEmpty else {
            DispatchQueue.main.async {
                onComplete(.failure(AIProviderError.serverError("DeepSeek requested web_search without a query.")))
            }
            return
        }
        
        let count = parseWebSearchCount(arguments: toolCall.arguments)
        SearXNGClient.shared.search(query: query, count: count) { result in
            let content: String
            switch result {
            case .success(let results):
                content = SearXNGClient.formatToolResult(query: query, results: results)
            case .failure(let error):
                content = "Web search failed for query: \(query). Error: \(error.localizedDescription)"
            }
            
            var nextMessages = originalMessages
            nextMessages.append(self.sanitizedAssistantToolMessage(assistantMessage))
            nextMessages.append([
                "role": "tool",
                "tool_call_id": toolCall.id,
                "content": content
            ])
            self.sendStreamRequestWithoutDeepSeekTools(messages: nextMessages, onUpdate: onUpdate, onComplete: onComplete)
        }
    }
    
    private func parseWebSearchQuery(arguments: String) -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = json["query"] as? String else {
            return ""
        }
        return query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseWebSearchCount(arguments: String) -> Int {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return UserSettings.shared.searxngResultCount
        }
        let requested = json["count"] as? Int ?? UserSettings.shared.searxngResultCount
        return max(1, min(requested, 10))
    }
    
    private func sanitizedAssistantToolMessage(_ message: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [
            "role": "assistant",
            "content": message["content"] as? String ?? ""
        ]
        if let reasoningContent = message["reasoning_content"] {
            sanitized["reasoning_content"] = reasoningContent
        }
        if let toolCalls = message["tool_calls"] {
            sanitized["tool_calls"] = toolCalls
        }
        return sanitized
    }
    
    private func sendStreamRequestWithoutDeepSeekTools(
        messages: [[String: Any]],
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        let originalConfig = config
        var noSearchConfig = config
        noSearchConfig.enableWebSearch = false
        config = noSearchConfig
        sendStreamRequest(messages: messages, onUpdate: onUpdate) { result in
            self.config = originalConfig
            onComplete(result)
        }
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let httpResponse = response as? HTTPURLResponse {
            httpStatusCode = httpResponse.statusCode
            print("[OpenAIClient] HTTP Status: \(httpStatusCode)")
        }
        completionHandler(.allow)
    }
    
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
            // Check HTTP status code 
            let statusCode = httpStatusCode != 0 ? httpStatusCode :
                (task.response as? HTTPURLResponse)?.statusCode ?? 200

            if statusCode != 200 {
                let rawBody = String(data: receiveBuffer, encoding: .utf8) ?? "None"
                print("[OpenAIClient] HTTP ERROR \(statusCode). Raw Body: \(rawBody)")
                
                // Try to extract error message from body
                var errorMessage = "HTTP \(statusCode): \(rawBody)"
                if let errorJson = try? JSONSerialization.jsonObject(with: receiveBuffer) as? [String: Any],
                   let errorObj = errorJson["error"] as? [String: Any],
                   let message = errorObj["message"] as? String {
                    errorMessage = message
                }
                
                let finalError: Error = statusCode == 429
                    ? AIProviderError.rateLimited
                    : NSError(domain: "AIProvider", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                
                DispatchQueue.main.async {
                    self.onStreamComplete?(.failure(finalError))
                }
            } else if fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("[OpenAIClient] Empty response received")
                DispatchQueue.main.async {
                    self.onStreamComplete?(.failure(AIProviderError.invalidResponse))
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
