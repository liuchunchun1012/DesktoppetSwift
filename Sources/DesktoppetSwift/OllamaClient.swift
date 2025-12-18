import Foundation

/// Client for communicating with local Ollama API
class OllamaClient: NSObject, URLSessionDataDelegate {
    static let shared = OllamaClient()

    private let baseURL = PetConfig.ollamaBaseURL
    private let defaultModel = PetConfig.defaultModel
    
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
            "model": model ?? defaultModel,
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
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let token = json["response"] as? String {
                    fullResponse += token
                    DispatchQueue.main.async {
                        self.onStreamUpdate?(self.fullResponse)
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
            DispatchQueue.main.async {
                self.onStreamComplete?(.success(self.fullResponse))
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
    
    /// Chat with streaming
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
        
        let prompt = """
        【当前时间】\(dateString)

        \(PetConfig.systemPrompt)

        \(PetConfig.ownerName): \(message)

        \(PetConfig.petName):
        """
        generateStream(prompt: prompt, onUpdate: onUpdate, onComplete: onComplete)
    }
    
    /// Non-streaming versions for compatibility
    func translate(text: String, from: String = "auto", to: String, completion: @escaping (Result<String, Error>) -> Void) {
        translateStream(text: text, to: to, onUpdate: { _ in }, onComplete: completion)
    }
    
    func chat(message: String, completion: @escaping (Result<String, Error>) -> Void) {
        chatStream(message: message, onUpdate: { _ in }, onComplete: completion)
    }
    
    /// Analyze an image with streaming (for vision models like gemma3)
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
        
        let prompt = """
        【当前时间】\(dateString)

        \(PetConfig.imageAnalysisPrompt)

        请分析这张图片，回答问题：\(userQuestion)
        """
        
        generateStream(
            prompt: prompt,
            images: [imageBase64],
            onUpdate: onUpdate,
            onComplete: onComplete
        )
    }
    
    /// Check if Ollama is running
    func checkHealth(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }.resume()
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
