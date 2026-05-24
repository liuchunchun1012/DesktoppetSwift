# DeepSeek SearXNG Tool Call Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-class DeepSeek provider with model-driven SearXNG web search tool calls, while leaving vision unsupported for DeepSeek.

**Architecture:** DeepSeek is routed through the existing OpenAI-compatible provider path, with a DeepSeek-specific branch in `OpenAICompatibleClient` that runs non-streaming tool-call detection followed by streaming final response. A new `SearXNGClient` owns public-instance fallback and result formatting, while `UserSettings` persists an optional custom SearXNG base URL and result count.

**Tech Stack:** Swift 5.7, SwiftUI settings UI, Foundation `URLSession`, existing UserDefaults/Keychain provider config, no external package dependencies.

---

## File Structure

- Modify `Sources/Meowpal/AIProvider.swift`: add `.deepseek`, display metadata, capability flags, defaults, and default token limits.
- Modify `Sources/Meowpal/AIProviderManager.swift`: route DeepSeek through `OpenAICompatibleClient` and return an unsupported image-analysis message for DeepSeek.
- Modify `Sources/Meowpal/SettingsWindow.swift`: show DeepSeek in provider picker automatically, save custom SearXNG settings in Advanced Settings, and make Base URL editable for DeepSeek.
- Modify `Sources/Meowpal/UserSettings.swift`: persist `searxngBaseURL` and `searxngResultCount`.
- Create `Sources/Meowpal/SearXNGClient.swift`: implement SearXNG search, public-instance fallback, and compact result formatting.
- Modify `Sources/Meowpal/OpenAICompatibleClient.swift`: add DeepSeek tool-call request/response structs, non-streaming tool-call loop, and final streaming request reuse.
- Optionally modify `README.md` and `使用说明.md`: list DeepSeek and describe SearXNG-backed web search.

### Task 1: Add DeepSeek Provider Metadata

**Files:**
- Modify: `Sources/Meowpal/AIProvider.swift`
- Modify: `Sources/Meowpal/AIProviderManager.swift`

- [ ] **Step 1: Add the enum case and provider metadata**

In `Sources/Meowpal/AIProvider.swift`, add `.deepseek` after `.qwen`:

```swift
case deepseek = "deepseek"
```

Update `displayName`:

```swift
case .deepseek: return "DeepSeek"
```

Update `defaultBaseURL`:

```swift
case .deepseek: return "https://api.deepseek.com"
```

Update `recommendedModels`:

```swift
case .deepseek:
    return ["deepseek-v4-flash", "deepseek-v4-pro", "deepseek-chat", "deepseek-reasoner"]
```

Update `supportsVision`:

```swift
case .deepseek: return false
```

Update `defaultMaxTokens`:

```swift
case .deepseek: return 8192
```

- [ ] **Step 2: Route DeepSeek through the OpenAI-compatible client**

In `Sources/Meowpal/AIProviderManager.swift`, update the OpenAI-compatible switch case:

```swift
case .openai, .grok, .qwen, .deepseek, .custom:
    return OpenAICompatibleClient(
        providerType: type,
        baseURL: config.baseURL,
        model: config.model
    )
```

- [ ] **Step 3: Verify the project still type-checks far enough to expose missing follow-up edits**

Run:

```bash
swift build
```

Expected: build may fail only if another switch over `AIProviderType` still needs a `.deepseek` case. Add the same `.deepseek` behavior to each reported exhaustive switch before continuing.

### Task 2: Add SearXNG Settings

**Files:**
- Modify: `Sources/Meowpal/UserSettings.swift`
- Modify: `Sources/Meowpal/SettingsWindow.swift`

- [ ] **Step 1: Persist SearXNG settings**

In `UserSettings.Keys`, add:

```swift
static let searxngBaseURL = "searxngBaseURL"
static let searxngResultCount = "searxngResultCount"
```

Add published properties:

```swift
@Published var searxngBaseURL: String {
    didSet {
        defaults.set(searxngBaseURL, forKey: Keys.searxngBaseURL)
    }
}

@Published var searxngResultCount: Int {
    didSet {
        defaults.set(searxngResultCount, forKey: Keys.searxngResultCount)
    }
}
```

Initialize them in `private init()`:

```swift
self.searxngBaseURL = defaults.string(forKey: Keys.searxngBaseURL) ?? ""
let savedSearxngResultCount = defaults.integer(forKey: Keys.searxngResultCount)
self.searxngResultCount = savedSearxngResultCount > 0 ? savedSearxngResultCount : 5
```

Reset them in `resetToDefaults()`:

```swift
searxngBaseURL = ""
searxngResultCount = 5
```

- [ ] **Step 2: Make DeepSeek Base URL editable**

In `AISettingsTab`, change:

```swift
if settings.currentProvider == .custom {
    TextField("Base URL", text: $baseURLInput)
}
```

to:

```swift
if settings.currentProvider == .custom || settings.currentProvider == .deepseek {
    TextField("Base URL", text: $baseURLInput)
}
```

In `saveConfig()`, change:

```swift
if type == .custom {
    config.baseURL = baseURLInput
}
```

to:

```swift
if type == .custom || type == .deepseek {
    config.baseURL = baseURLInput
}
```

- [ ] **Step 3: Add DeepSeek-specific SearXNG controls**

Inside the Advanced Settings `DisclosureGroup`, after the `Enable Web Search` toggle, add:

```swift
if settings.currentProvider == .deepseek {
    TextField("SearXNG URL (optional)", text: $settings.searxngBaseURL)
    Text("Leave blank to use bundled public SearXNG instances.")
        .font(.caption)
        .foregroundColor(.secondary)

    Stepper("Search Results: \(settings.searxngResultCount)", value: $settings.searxngResultCount, in: 1...10)
}
```

- [ ] **Step 4: Run build**

Run:

```bash
swift build
```

Expected: PASS, or only errors caused by not-yet-implemented DeepSeek tool-call code in later tasks if Task 3 has already started.

### Task 3: Create SearXNG Client

**Files:**
- Create: `Sources/Meowpal/SearXNGClient.swift`

- [ ] **Step 1: Create result models and URL normalization**

Create `Sources/Meowpal/SearXNGClient.swift` with:

```swift
import Foundation

struct SearXNGSearchResult: Codable {
    let title: String
    let url: String
    let content: String
}

private struct SearXNGResponse: Decodable {
    let results: [SearXNGResult]
}

private struct SearXNGResult: Decodable {
    let title: String?
    let url: String?
    let content: String?
}

enum SearXNGError: Error, LocalizedError {
    case noUsableInstance
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .noUsableInstance:
            return "No available SearXNG instance returned JSON search results."
        case .invalidURL(let value):
            return "Invalid SearXNG URL: \(value)"
        }
    }
}
```

- [ ] **Step 2: Add the client implementation**

Append:

```swift
final class SearXNGClient {
    static let shared = SearXNGClient()

    private let publicInstances = [
        "https://searx.be",
        "https://search.sapti.me",
        "https://searx.tiekoetter.com",
        "https://searxng.world"
    ]

    private init() {}

    func search(query: String, count: Int, completion: @escaping (Result<[SearXNGSearchResult], Error>) -> Void) {
        let customBaseURL = UserSettings.shared.searxngBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let bases = ([customBaseURL].filter { !$0.isEmpty } + publicInstances)
        search(query: query, count: count, bases: bases, index: 0, completion: completion)
    }

    private func search(
        query: String,
        count: Int,
        bases: [String],
        index: Int,
        completion: @escaping (Result<[SearXNGSearchResult], Error>) -> Void
    ) {
        guard index < bases.count else {
            completion(.failure(SearXNGError.noUsableInstance))
            return
        }

        guard let url = makeSearchURL(base: bases[index], query: query) else {
            search(query: query, count: count, bases: bases, index: index + 1, completion: completion)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Meowpal/DeepSeekWebSearch", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[SearXNG] Instance failed: \(bases[index]) \(error.localizedDescription)")
                self.search(query: query, count: count, bases: bases, index: index + 1, completion: completion)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data,
                  let decoded = try? JSONDecoder().decode(SearXNGResponse.self, from: data) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[SearXNG] Instance returned unusable response: \(bases[index]) status=\(status)")
                self.search(query: query, count: count, bases: bases, index: index + 1, completion: completion)
                return
            }

            let limit = max(1, min(count, 10))
            let results = decoded.results.compactMap { result -> SearXNGSearchResult? in
                guard let title = result.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let url = result.url?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !title.isEmpty,
                      !url.isEmpty else {
                    return nil
                }

                let content = result.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return SearXNGSearchResult(title: title, url: url, content: content)
            }
            .prefix(limit)

            completion(.success(Array(results)))
        }.resume()
    }

    private func makeSearchURL(base: String, query: String) -> URL? {
        let trimmed = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: "\(trimmed)/search") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "language", value: "auto"),
            URLQueryItem(name: "safesearch", value: "1")
        ]
        return components.url
    }

    static func formatToolResult(query: String, results: [SearXNGSearchResult]) -> String {
        guard !results.isEmpty else {
            return "No web results found for query: \(query)"
        }

        var lines = ["Web search results for: \(query)"]
        for (index, result) in results.enumerated() {
            lines.append("""

            [\(index + 1)] \(result.title)
            URL: \(result.url)
            Snippet: \(result.content.isEmpty ? "No snippet available." : result.content)
            """)
        }
        return lines.joined(separator: "\n")
    }
}
```

- [ ] **Step 3: Run build**

Run:

```bash
swift build
```

Expected: PASS, because the new file is compiled automatically by SwiftPM.

### Task 4: Add DeepSeek Tool-Call Flow

**Files:**
- Modify: `Sources/Meowpal/OpenAICompatibleClient.swift`

- [ ] **Step 1: Add DeepSeek branch before normal streaming**

At the start of `sendStreamRequest(messages:onUpdate:onComplete:)`, before building the streaming URL, add:

```swift
if providerType == .deepseek && config.enableWebSearch {
    sendDeepSeekToolRequest(messages: messages, onUpdate: onUpdate, onComplete: onComplete)
    return
}
```

- [ ] **Step 2: Add helper models**

Inside `OpenAICompatibleClient`, before `// MARK: - URLSessionDataDelegate`, add:

```swift
private struct DeepSeekToolCall {
    let id: String
    let name: String
    let arguments: String
}
```

- [ ] **Step 3: Add non-streaming tool-call request**

Add:

```swift
private func sendDeepSeekToolRequest(
    messages: [[String: Any]],
    onUpdate: @escaping (String) -> Void,
    onComplete: @escaping (Result<String, Error>) -> Void
) {
    guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
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
```

- [ ] **Step 4: Add tool schema and response handling**

Add:

```swift
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
                    onComplete(.success(cleanModelOutput(content)))
                }
            } else {
                DispatchQueue.main.async { onComplete(.failure(AIProviderError.invalidResponse)) }
            }
            return
        }

        executeDeepSeekToolCalls(toolCalls, originalMessages: originalMessages, assistantMessage: message, onUpdate: onUpdate, onComplete: onComplete)
    } catch {
        DispatchQueue.main.async { onComplete(.failure(error)) }
    }
}
```

- [ ] **Step 5: Parse and execute web_search calls**

Add:

```swift
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

private func executeDeepSeekToolCalls(
    _ toolCalls: [DeepSeekToolCall],
    originalMessages: [[String: Any]],
    assistantMessage: [String: Any],
    onUpdate: @escaping (String) -> Void,
    onComplete: @escaping (Result<String, Error>) -> Void
) {
    let group = DispatchGroup()
    var toolMessages: [[String: Any]] = []

    for toolCall in toolCalls where toolCall.name == "web_search" {
        group.enter()
        let query = parseWebSearchQuery(arguments: toolCall.arguments)
        let count = parseWebSearchCount(arguments: toolCall.arguments)

        SearXNGClient.shared.search(query: query, count: count) { result in
            let content: String
            switch result {
            case .success(let results):
                content = SearXNGClient.formatToolResult(query: query, results: results)
            case .failure(let error):
                content = "Web search failed for query: \(query). Error: \(error.localizedDescription)"
            }

            toolMessages.append([
                "role": "tool",
                "tool_call_id": toolCall.id,
                "content": content
            ])
            group.leave()
        }
    }

    group.notify(queue: .main) {
        var nextMessages = originalMessages
        nextMessages.append(self.sanitizedAssistantToolMessage(assistantMessage))
        nextMessages.append(contentsOf: toolMessages)
        self.sendStreamRequestWithoutDeepSeekTools(messages: nextMessages, onUpdate: onUpdate, onComplete: onComplete)
    }
}
```

- [ ] **Step 6: Add argument parsers and final streaming helper**

Add:

```swift
private func parseWebSearchQuery(arguments: String) -> String {
    guard let data = arguments.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let query = json["query"] as? String,
          !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return ""
    }
    return query
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
```

- [ ] **Step 7: Preserve tool message content in the normal streaming path**

In the standard OpenAI message cleaning branch, replace the string-only cleaner with:

```swift
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
```

- [ ] **Step 8: Run build**

Run:

```bash
swift build
```

Expected: PASS. If Swift reports closure capture ordering around `toolMessages`, serialize tool-call execution because the first implementation only needs one `web_search` call.

### Task 5: DeepSeek Image Analysis Unsupported Message

**Files:**
- Modify: `Sources/Meowpal/AIProviderManager.swift`

- [ ] **Step 1: Return a clear unsupported message**

At the start of `analyzeImageStream(imageBase64:question:onUpdate:onComplete:)`, after provider existence check, add:

```swift
if currentProviderType == .deepseek {
    let message = "DeepSeek mode currently supports text chat and SearXNG web search, but not image analysis. Please switch to a vision-capable provider such as OpenAI, Gemini, Qwen, Claude, Grok, or Ollama for screenshots."
    onUpdate(message)
    onComplete(.success(message))
    return
}
```

- [ ] **Step 2: Run build**

Run:

```bash
swift build
```

Expected: PASS.

### Task 6: Documentation and Final Verification

**Files:**
- Modify: `README.md`
- Modify: `使用说明.md`

- [ ] **Step 1: Update provider lists**

In both docs, add DeepSeek to supported provider lists:

```markdown
Ollama / OpenAI / Claude / Gemini / Grok / Qwen / DeepSeek / Custom API
```

Add a provider table row:

```markdown
| **DeepSeek** | Text chat with SearXNG-backed web search tool calls | ✅ |
```

- [ ] **Step 2: Add DeepSeek search note**

Add a short note near AI configuration:

```markdown
DeepSeek web search uses model tool calls plus SearXNG. The app tries bundled public SearXNG instances by default; optional custom SearXNG URL can be set in Advanced Settings.
```

- [ ] **Step 3: Final build**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 4: Inspect git diff**

Run:

```bash
git diff -- Sources/Meowpal/AIProvider.swift Sources/Meowpal/AIProviderManager.swift Sources/Meowpal/OpenAICompatibleClient.swift Sources/Meowpal/SearXNGClient.swift Sources/Meowpal/SettingsWindow.swift Sources/Meowpal/UserSettings.swift README.md 使用说明.md
```

Expected: changes are limited to DeepSeek provider metadata, SearXNG settings/client, DeepSeek tool-call flow, image unsupported behavior, and docs.

- [ ] **Step 5: Commit implementation**

Run:

```bash
git add Sources/Meowpal/AIProvider.swift Sources/Meowpal/AIProviderManager.swift Sources/Meowpal/OpenAICompatibleClient.swift Sources/Meowpal/SearXNGClient.swift Sources/Meowpal/SettingsWindow.swift Sources/Meowpal/UserSettings.swift README.md 使用说明.md
git commit -m "feat: add DeepSeek SearXNG web search"
```
