import Foundation

final class OpenCodeClient: AIProvider {
    struct ModelSelection: Equatable {
        let providerID: String
        let modelID: String
    }

    let providerType: AIProviderType = .opencode
    var currentModel: String

    private let baseURL: String
    private let agent: String?
    private let enableTools: Bool
    private var sessionID: String?
    private var activeTask: URLSessionDataTask?

    init(baseURL: String, model: String, agent: String? = nil, enableTools: Bool = true) {
        self.baseURL = Self.normalizeBaseURL(baseURL)
        self.currentModel = model
        self.agent = Self.sanitizeAgent(agent)
        self.enableTools = enableTools
    }

    convenience init(config: ProviderConfiguration) {
        self.init(
            baseURL: config.baseURL,
            model: config.model,
            agent: config.agent,
            enableTools: config.enableWebSearch
        )
    }

    var isConfigured: Bool {
        !baseURL.isEmpty
    }

    func chatStream(
        message: String,
        history: [[String: String]],
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        ensureSession { result in
            switch result {
            case .failure(let error):
                onComplete(.failure(error))
            case .success(let sessionID):
                self.sendPrompt(sessionID: sessionID, message: message, systemPrompt: systemPrompt, onUpdate: onUpdate, onComplete: onComplete)
            }
        }
    }

    func analyzeImageStream(
        imageBase64: String,
        question: String,
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        ensureSession { result in
            switch result {
            case .failure(let error):
                onComplete(.failure(error))
            case .success(let sessionID):
                self.sendImagePrompt(
                    sessionID: sessionID,
                    imageBase64: imageBase64,
                    question: question,
                    systemPrompt: systemPrompt,
                    onUpdate: onUpdate,
                    onComplete: onComplete
                )
            }
        }
    }

    func checkHealth(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/doc") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        activeTask = URLSession.shared.dataTask(with: request) { data, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
                && data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["openapi"] != nil
            DispatchQueue.main.async { completion(ok) }
        }
        activeTask?.resume()
    }

    func cancelCurrentRequest() {
        activeTask?.cancel()
        activeTask = nil
    }

    static func normalizeBaseURL(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func parseModel(_ value: String) -> ModelSelection? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            return nil
        }
        return ModelSelection(providerID: parts[0], modelID: parts[1])
    }

    static func sanitizeAgent(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            print("[OpenCodeClient] Ignoring invalid agent name with whitespace: \(trimmed)")
            return nil
        }
        return trimmed
    }

    static func buildPromptBody(message: String, systemPrompt: String, model: String, agent: String?, enableTools: Bool) throws -> Data {
        var body: [String: Any] = [
            "parts": [["type": "text", "text": message]]
        ]

        addCommonPromptFields(to: &body, systemPrompt: systemPrompt, model: model, agent: agent, enableTools: enableTools)

        return try JSONSerialization.data(withJSONObject: body)
    }

    static func buildImagePromptBody(imageBase64: String, question: String, systemPrompt: String, model: String, agent: String?, enableTools: Bool) throws -> Data {
        var body: [String: Any] = [
            "parts": [
                ["type": "text", "text": question],
                [
                    "type": "file",
                    "mime": "image/png",
                    "filename": "meowpal-screenshot.png",
                    "url": "data:image/png;base64,\(imageBase64)"
                ]
            ]
        ]

        addCommonPromptFields(to: &body, systemPrompt: systemPrompt, model: model, agent: agent, enableTools: enableTools)

        return try JSONSerialization.data(withJSONObject: body)
    }

    private static func addCommonPromptFields(to body: inout [String: Any], systemPrompt: String, model: String, agent: String?, enableTools: Bool) {

        let trimmedSystem = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSystem.isEmpty {
            body["system"] = trimmedSystem
        }

        if let selection = parseModel(model) {
            body["model"] = ["providerID": selection.providerID, "modelID": selection.modelID]
        }

        if let agent = sanitizeAgent(agent) {
            body["agent"] = agent
        }

        if enableTools {
            body["tools"] = ["*": true]
        }
    }

    static func extractLatestAssistantText(from messages: [[String: Any]]) -> String? {
        for message in messages.reversed() {
            guard let info = message["info"] as? [String: Any], info["role"] as? String == "assistant" else {
                continue
            }
            guard let parts = message["parts"] as? [[String: Any]] else {
                continue
            }
            let text = parts.compactMap { part -> String? in
                guard part["type"] as? String == "text" else { return nil }
                return part["text"] as? String
            }.joined()
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }
        return nil
    }

    private func ensureSession(completion: @escaping (Result<String, Error>) -> Void) {
        if let sessionID {
            completion(.success(sessionID))
            return
        }

        guard let url = URL(string: "\(baseURL)/session") else {
            completion(.failure(AIProviderError.notConfigured))
            return
        }

        var body: [String: Any] = ["title": "Meowpal"]
        if let agent {
            body["agent"] = agent
        }
        if let selection = Self.parseModel(currentModel) {
            body["model"] = ["id": selection.modelID, "providerID": selection.providerID]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        activeTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data, (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = json["id"] as? String else {
                DispatchQueue.main.async { completion(.failure(AIProviderError.invalidResponse)) }
                return
            }
            self.sessionID = id
            DispatchQueue.main.async { completion(.success(id)) }
        }
        activeTask?.resume()
    }

    private func sendPrompt(
        sessionID: String,
        message: String,
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/session/\(sessionID)/message") else {
            onComplete(.failure(AIProviderError.notConfigured))
            return
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.buildPromptBody(message: message, systemPrompt: systemPrompt, model: currentModel, agent: agent, enableTools: enableTools)

            print("[OpenCodeClient] Sending prompt to \(url)")
            activeTask = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    DispatchQueue.main.async { onComplete(.failure(error)) }
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse, let data else {
                    DispatchQueue.main.async { onComplete(.failure(AIProviderError.invalidResponse)) }
                    return
                }
                print("[OpenCodeClient] HTTP Status: \(httpResponse.statusCode)")
                guard (200...299).contains(httpResponse.statusCode) else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    DispatchQueue.main.async { onComplete(.failure(AIProviderError.serverError("HTTP \(httpResponse.statusCode): \(body.prefix(500))"))) }
                    return
                }

                let text = self.extractTextFromPromptResponse(data)
                DispatchQueue.main.async {
                    guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        onComplete(.failure(AIProviderError.invalidResponse))
                        return
                    }
                    let cleaned = self.cleanModelOutput(text)
                    onUpdate(cleaned)
                    onComplete(.success(cleaned))
                }
            }
            activeTask?.resume()
        } catch {
            onComplete(.failure(error))
        }
    }

    private func sendImagePrompt(
        sessionID: String,
        imageBase64: String,
        question: String,
        systemPrompt: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/session/\(sessionID)/message") else {
            onComplete(.failure(AIProviderError.notConfigured))
            return
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.buildImagePromptBody(
                imageBase64: imageBase64,
                question: question,
                systemPrompt: systemPrompt,
                model: currentModel,
                agent: agent,
                enableTools: enableTools
            )

            print("[OpenCodeClient] Sending image prompt to \(url)")
            activeTask = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    DispatchQueue.main.async { onComplete(.failure(error)) }
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse, let data else {
                    DispatchQueue.main.async { onComplete(.failure(AIProviderError.invalidResponse)) }
                    return
                }
                print("[OpenCodeClient] Image HTTP Status: \(httpResponse.statusCode)")
                guard (200...299).contains(httpResponse.statusCode) else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    DispatchQueue.main.async { onComplete(.failure(AIProviderError.serverError("HTTP \(httpResponse.statusCode): \(body.prefix(500))"))) }
                    return
                }

                let text = self.extractTextFromPromptResponse(data)
                DispatchQueue.main.async {
                    guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        onComplete(.failure(AIProviderError.invalidResponse))
                        return
                    }
                    let cleaned = self.cleanModelOutput(text)
                    onUpdate(cleaned)
                    onComplete(.success(cleaned))
                }
            }
            activeTask?.resume()
        } catch {
            onComplete(.failure(error))
        }
    }

    private func extractTextFromPromptResponse(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let parts = json["parts"] as? [[String: Any]] {
            let text = parts.compactMap { part -> String? in
                guard part["type"] as? String == "text" else { return nil }
                return part["text"] as? String
            }.joined()
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }

        if let messages = json["messages"] as? [[String: Any]] {
            return Self.extractLatestAssistantText(from: messages)
        }

        return nil
    }
}
