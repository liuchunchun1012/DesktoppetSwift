import Foundation

/// Client for communicating with local Ollama API
class OllamaClient: NSObject, AIProvider, URLSessionDataDelegate {
    static let shared = OllamaClient()

    private let baseURL = PetConfig.ollamaBaseURL
    
    // MARK: - AIProvider Protocol
    
    let providerType: AIProviderType = .ollama
    
    var currentModel: String {
        get { UserSettings.shared.getConfig(for: .ollama).model }
        set { 
            var config = UserSettings.shared.getConfig(for: .ollama)
            config.model = newValue
            UserSettings.shared.updateConfig(config)
        }
    }
    
    var isConfigured: Bool { true }  // Ollama 不需要 API Key
    
    // Chat memory - keeps last N rounds of conversation (in memory only)
    private let maxHistoryRounds = 20
    private var chatHistory: [[String: String]] = []
    
    private var streamSession: URLSession?
    private var streamData = Data()
    private var onStreamUpdate: ((String) -> Void)?
    private var onStreamComplete: ((Result<String, Error>) -> Void)?
    private var fullResponse = ""
    
    override init() {
        super.init()
    }
    
    /// Generate a response with streaming output
    func generateStream(
        prompt: String,
        model: String? = nil,
        images: [String]? = nil,  // Base64 encoded images for vision models
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "model": model ?? currentModel,
            "prompt": prompt,
            "stream": true  // Enable streaming
        ]
        
        // Add images if provided (for vision models)
        if let images = images, !images.isEmpty {
            body["images"] = images
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            onComplete(.failure(error))
            return
        }
        
        // Store callbacks
        self.onStreamUpdate = onUpdate
        self.onStreamComplete = onComplete
        self.fullResponse = ""
        self.streamData = Data()
        
        // Create session with delegate for streaming
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        streamSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        let task = streamSession?.dataTask(with: request)
        task?.resume()
    }
    
    // URLSessionDataDelegate method for streaming data
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Each chunk is a JSON line
        if let chunk = String(data: data, encoding: .utf8) {
            // Split by newlines in case multiple JSON objects are in one chunk
            let lines = chunk.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            for line in lines {
                if let jsonData = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    // Handle /api/generate format: {"response": "token"}
                    // Handle /api/chat format: {"message": {"content": "token"}}
                    var token: String?
                    if let response = json["response"] as? String {
                        token = response
                    } else if let message = json["message"] as? [String: Any],
                              let content = message["content"] as? String {
                        token = content
                    }
                    
                    if let token = token {
                        fullResponse += token
                        DispatchQueue.main.async {
                            self.onStreamUpdate?(self.fullResponse)
                        }
                    }
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.onStreamComplete?(.failure(error))
            }
        } else {
            // Filter out model artifacts like "end of turn" and "start of turn"
            var cleanedResponse = self.fullResponse
            let artifactsToRemove = ["<end_of_turn>", "end of turn", "<start_of_turn>", "start of turn", "<|eot_id|>", "<|end|>", "<|start|>", "model"]
            for artifact in artifactsToRemove {
                cleanedResponse = cleanedResponse.replacingOccurrences(of: artifact, with: "", options: .caseInsensitive)
            }
            cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            
            DispatchQueue.main.async {
                self.onStreamComplete?(.success(cleanedResponse))
            }
        }
        
        // Cleanup
        streamSession?.invalidateAndCancel()
        streamSession = nil
    }
    
    /// Generate without streaming (for compatibility)
    func generate(prompt: String, model: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        generateStream(prompt: prompt, model: model, onUpdate: { _ in }, onComplete: completion)
    }
    
    /// Translate text with streaming
    func translateStream(
        text: String,
        to targetLanguage: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        let prompt = """
        Translate the following text to \(targetLanguage). Only output the translation, nothing else.
        
        Text: \(text)
        
        Translation:
        """
        generateStream(prompt: prompt, onUpdate: onUpdate, onComplete: onComplete)
    }
    
    /// Chat with streaming and memory
    func chatStream(
        message: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        // Get current date/time for context
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 EEEE HH:mm"
        let dateString = formatter.string(from: now)
        
        // Build system message with time context
        let systemContent = """
        【当前时间】\(dateString)
        
        \(PetConfig.systemPrompt)
        """
        
        // Add user message to history
        chatHistory.append(["role": "user", "content": message])
        
        // Trim history to keep only last N rounds (each round = 2 messages)
        let maxMessages = maxHistoryRounds * 2
        if chatHistory.count > maxMessages {
            chatHistory = Array(chatHistory.suffix(maxMessages))
        }
        
        // Build messages array for Ollama /api/chat
        var messages: [[String: String]] = [
            ["role": "system", "content": systemContent]
        ]
        messages.append(contentsOf: chatHistory)
        
        // Use /api/chat endpoint
        let url = URL(string: "\(baseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": currentModel,
            "messages": messages,
            "stream": true
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            onComplete(.failure(error))
            return
        }
        
        // Store callbacks
        self.onStreamUpdate = onUpdate
        self.onStreamComplete = { [weak self] result in
            // On success, add assistant response to history
            if case .success(let response) = result {
                self?.chatHistory.append(["role": "assistant", "content": response])
            }
            onComplete(result)
        }
        self.fullResponse = ""
        self.streamData = Data()
        
        // Create session with delegate for streaming
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        streamSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        let task = streamSession?.dataTask(with: request)
        task?.resume()
    }
    
    /// Clear chat history
    func clearChatHistory() {
        chatHistory.removeAll()
        print("[OllamaClient] Chat history cleared")
    }
    
    /// Non-streaming versions for compatibility
    func translate(text: String, from: String = "auto", to: String, completion: @escaping (Result<String, Error>) -> Void) {
        translateStream(text: text, to: to, onUpdate: { _ in }, onComplete: completion)
    }
    
    func chat(message: String, completion: @escaping (Result<String, Error>) -> Void) {
        chatStream(message: message, onUpdate: { _ in }, onComplete: completion)
    }
    
    /// Analyze an image with streaming (for vision models like gemma3)
    /// Also adds the Q&A to chat history so follow-up questions have context
    func analyzeImageStream(
        imageBase64: String,
        question: String? = nil,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        // Get current date/time for context
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 EEEE HH:mm"
        let dateString = formatter.string(from: now)
        
        let userQuestion = question ?? "请描述这张图片的内容"
        
        // Add user question to chat history (with note about image)
        let historyMessage = "[用户发送了一张图片] \(userQuestion)"
        chatHistory.append(["role": "user", "content": historyMessage])
        
        // Trim history if needed
        let maxMessages = maxHistoryRounds * 2
        if chatHistory.count > maxMessages {
            chatHistory = Array(chatHistory.suffix(maxMessages))
        }
        
        let prompt = """
        【当前时间】\(dateString)

        \(PetConfig.imageAnalysisPrompt)

        请分析这张图片，回答问题：\(userQuestion)
        """
        
        generateStream(
            prompt: prompt,
            images: [imageBase64],
            onUpdate: onUpdate,
            onComplete: { [weak self] result in
                // Add assistant response to chat history
                if case .success(let response) = result {
                    self?.chatHistory.append(["role": "assistant", "content": response])
                }
                onComplete(result)
            }
        )
    }
    
    /// Check if Ollama is running
    func checkHealth(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: url) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                DispatchQueue.main.async {
                    completion(httpResponse.statusCode == 200)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    /// Cancel current request (AIProvider protocol)
    func cancelCurrentRequest() {
        streamSession?.invalidateAndCancel()
        streamSession = nil
        onStreamComplete?(.failure(AIProviderError.cancelled))
        onStreamComplete = nil
        onStreamUpdate = nil
    }
    
    // MARK: - AIProvider Protocol Methods
    
    /// Chat with streaming (AIProvider protocol)
    func chatStream(
        message: String,
        history: [[String: String]],
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        // Build messages array for Ollama /api/chat
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        messages.append(contentsOf: history)
        messages.append(["role": "user", "content": message])
        
        let url = URL(string: "\(baseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": currentModel,
            "messages": messages,
            "stream": true
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            onComplete(.failure(error))
            return
        }
        
        self.onStreamUpdate = onUpdate
        self.onStreamComplete = onComplete
        self.fullResponse = ""
        self.streamData = Data()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        streamSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        let task = streamSession?.dataTask(with: request)
        task?.resume()
    }
    
    /// Analyze image with streaming (AIProvider protocol)
    func analyzeImageStream(
        imageBase64: String,
        question: String,
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        let prompt = """
        \(systemPrompt)
        
        请分析这张图片，回答问题：\(question)
        """
        
        generateStream(
            prompt: prompt,
            images: [imageBase64],
            onUpdate: onUpdate,
            onComplete: onComplete
        )
    }
}

enum OllamaError: Error, LocalizedError {
    case noData
    case invalidResponse
    case modelNotFound
    
    var errorDescription: String? {
        switch self {
        case .noData: return "No data received from Ollama"
        case .invalidResponse: return "Invalid response format"
        case .modelNotFound: return "Model not found in Ollama"
        }
    }
}
