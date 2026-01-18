import Foundation

/// Google Gemini API 客户端
class GeminiClient: NSObject, AIProvider, URLSessionDataDelegate {
    
    // MARK: - Properties

    let providerType: AIProviderType = .gemini
    var currentModel: String

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let apiKey: String
    private var config: ProviderConfiguration

    private var streamSession: URLSession?
    private var fullResponse = ""
    private var onStreamUpdate: ((String) -> Void)?
    private var onStreamComplete: ((Result<String, Error>) -> Void)?
    private var accumulatedData = Data()

    // MARK: - Initialization

    init(apiKey: String, model: String = "gemini-2.0-flash", config: ProviderConfiguration? = nil) {
        self.apiKey = apiKey
        self.currentModel = model
        self.config = config ?? UserSettings.shared.getConfig(for: .gemini)
        super.init()
    }

    /// 便捷初始化：从 Keychain 读取 API Key
    convenience init?(model: String? = nil) {
        guard let apiKey = KeychainHelper.shared.getAPIKey(for: .gemini), !apiKey.isEmpty else {
            return nil
        }
        let config = UserSettings.shared.getConfig(for: .gemini)
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
        // 构建 Gemini 格式的内容
        var contents: [[String: Any]] = []
        
        // 添加历史消息
        for msg in history {
            if let role = msg["role"], let content = msg["content"] {
                let geminiRole = role == "user" ? "user" : "model"
                contents.append([
                    "role": geminiRole,
                    "parts": [["text": content]]
                ])
            }
        }
        
        // 添加当前消息
        contents.append([
            "role": "user",
            "parts": [["text": message]]
        ])
        
        sendStreamRequest(
            contents: contents,
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
        // Gemini 图片格式
        let contents: [[String: Any]] = [
            [
                "role": "user",
                "parts": [
                    [
                        "inline_data": [
                            "mime_type": "image/png",
                            "data": imageBase64
                        ]
                    ],
                    ["text": question]
                ]
            ]
        ]
        
        sendStreamRequest(
            contents: contents,
            systemPrompt: systemPrompt,
            onUpdate: onUpdate,
            onComplete: onComplete
        )
    }
    
    func checkHealth(completion: @escaping (Bool) -> Void) {
        // 验证模型是否存在：调用 models/model_name 接口
        let modelCheckURL = "\(baseURL)/models/\(currentModel)?key=\(apiKey)"
        guard let url = URL(string: modelCheckURL) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // 成功：模型存在
                    print("[GeminiClient] Model '\(self.currentModel)' verified")
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } else if httpResponse.statusCode == 404 {
                    // 404：模型不存在
                    print("[GeminiClient] Model '\(self.currentModel)' NOT FOUND")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                } else {
                    // 其他错误（可能是 API Key 问题）
                    print("[GeminiClient] API Error: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        completion(false)
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
        contents: [[String: Any]],
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        let urlString = "\(baseURL)/models/\(currentModel):streamGenerateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            onComplete(.failure(AIProviderError.invalidResponse))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "contents": contents
        ]
        
        // 添加系统指令
        if !systemPrompt.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": systemPrompt]]
            ]
        }
        
        // 配置生成参数（使用用户设置）
        body["generationConfig"] = [
            "maxOutputTokens": config.maxTokens,
            "temperature": config.temperature,
            "topP": config.topP,
            "topK": 40
        ]

        // 启用 Google Search 联网功能（如果启用）
        if config.enableWebSearch {
            body["tools"] = [
                ["google_search": [:]]
            ]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            request.httpBody = jsonData
            
            // 打印完整请求体用于调试
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("[GeminiClient] ===== REQUEST =====")
                print("[GeminiClient] URL: \(urlString)")
                print("[GeminiClient] Body: \(jsonString)")
                print("[GeminiClient] ====================")
            }
        } catch {
            onComplete(.failure(error))
            return
        }
        
        self.onStreamUpdate = onUpdate
        self.onStreamComplete = onComplete
        self.fullResponse = ""
        self.accumulatedData = Data()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        streamSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        let task = streamSession?.dataTask(with: request)
        task?.resume()
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        accumulatedData.append(data)
        
        // 尝试解析收到的数据
        guard let text = String(data: accumulatedData, encoding: .utf8) else {
            print("[GeminiClient] Failed to decode data as UTF-8")
            return
        }
        
        print("[GeminiClient] Received data: \(text.prefix(500))...")
        
        // Gemini 流式返回格式是一个 JSON 数组 [{...}, {...}, ...]
        // 但可能是不完整的，需要尝试解析
        
        // 尝试直接解析为 JSON 数组
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果不是以 ] 结尾，尝试添加 ] 来使其成为有效 JSON
        if !jsonText.hasSuffix("]") && jsonText.hasPrefix("[") {
            jsonText = jsonText + "]"
        }
        
        // 解析 JSON 数组
        guard let jsonData = jsonText.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            // 如果解析失败，可能是数据还不完整，等待更多数据
            return
        }
        
        // 提取所有文本片段
        var allText = ""
        for item in jsonArray {
            if let candidates = item["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]] {
                for part in parts {
                    if let partText = part["text"] as? String {
                        allText += partText
                    }
                }
            }
        }
        
        if !allText.isEmpty && allText != fullResponse {
            fullResponse = allText
            print("[GeminiClient] Extracted text: \(fullResponse.prefix(200))...")
            DispatchQueue.main.async {
                self.onStreamUpdate?(self.fullResponse)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("[GeminiClient] Request failed with error: \(error)")
            DispatchQueue.main.async {
                self.onStreamComplete?(.failure(AIProviderError.networkError(error)))
            }
        } else {
            // 最终解析完整响应
            guard let text = String(data: accumulatedData, encoding: .utf8) else {
                print("[GeminiClient] Failed to decode final data")
                DispatchQueue.main.async {
                    self.onStreamComplete?(.failure(AIProviderError.invalidResponse))
                }
                return
            }
            
            print("[GeminiClient] Final data: \(text.prefix(500))...")
            
            // 检查是否有错误响应
            if let errorData = accumulatedData as Data?,
               let errorJson = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("[GeminiClient] API Error: \(message)")
                DispatchQueue.main.async {
                    self.onStreamComplete?(.failure(AIProviderError.serverError(message)))
                }
                return
            }
            
            // 尝试解析最终的 JSON 数组
            if let json = try? JSONSerialization.jsonObject(with: accumulatedData) as? [[String: Any]] {
                var finalText = ""
                for item in json {
                    if let candidates = item["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]] {
                        for part in parts {
                            if let partText = part["text"] as? String {
                                finalText += partText
                            }
                        }
                    }
                }
                if !finalText.isEmpty {
                    fullResponse = finalText
                }
            }
            
            print("[GeminiClient] Final response: \(fullResponse.prefix(200))...")
            
            let cleaned = cleanModelOutput(fullResponse)
            DispatchQueue.main.async {
                self.onStreamComplete?(.success(cleaned))
            }
        }
        
        streamSession?.invalidateAndCancel()
        streamSession = nil
        accumulatedData = Data()
    }
}
