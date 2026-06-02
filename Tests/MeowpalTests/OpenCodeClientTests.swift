import Foundation
import Testing
@testable import Meowpal

@Suite("OpenCodeClient")
struct OpenCodeClientTests {
    @Test func normalizeBaseURLTrimsTrailingSlashes() {
        #expect(OpenCodeClient.normalizeBaseURL("http://127.0.0.1:4096///") == "http://127.0.0.1:4096")
    }

    @Test func parseModelSplitsProviderAndModel() {
        #expect(
            OpenCodeClient.parseModel("anthropic/claude-sonnet-4-5") ==
            OpenCodeClient.ModelSelection(providerID: "anthropic", modelID: "claude-sonnet-4-5")
        )
    }

    @Test func parseModelRejectsBlankAndUnqualifiedModels() {
        #expect(OpenCodeClient.parseModel("") == nil)
        #expect(OpenCodeClient.parseModel("claude-sonnet-4-5") == nil)
    }

    @Test func buildPromptBodyIncludesSystemAgentModelAndTools() throws {
        let data = try OpenCodeClient.buildPromptBody(
            message: "search latest Swift news",
            systemPrompt: "You are Meowpal.",
            model: "anthropic/claude-sonnet-4-5",
            agent: "build",
            enableTools: true
        )

        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["system"] as? String == "You are Meowpal.")
        #expect(body["agent"] as? String == "build")

        let model = try #require(body["model"] as? [String: Any])
        #expect(model["providerID"] as? String == "anthropic")
        #expect(model["modelID"] as? String == "claude-sonnet-4-5")

        let tools = try #require(body["tools"] as? [String: Bool])
        #expect(tools["*"] == true)

        let parts = try #require(body["parts"] as? [[String: Any]])
        #expect(parts.count == 1)
        #expect(parts[0]["type"] as? String == "text")
        #expect(parts[0]["text"] as? String == "search latest Swift news")
    }

    @Test func buildPromptBodyOmitsInvalidAgentWithSpaces() throws {
        let data = try OpenCodeClient.buildPromptBody(
            message: "hi",
            systemPrompt: "",
            model: "",
            agent: "Kimi K2.6",
            enableTools: true
        )

        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["agent"] == nil)
    }

    @Test func buildImagePromptBodyIncludesTextAndPngFileParts() throws {
        let data = try OpenCodeClient.buildImagePromptBody(
            imageBase64: "abc123",
            question: "What is shown?",
            systemPrompt: "Analyze screenshots.",
            model: "openai/gpt-4o",
            agent: "build",
            enableTools: true
        )

        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["system"] as? String == "Analyze screenshots.")

        let parts = try #require(body["parts"] as? [[String: Any]])
        #expect(parts.count == 2)
        #expect(parts[0]["type"] as? String == "text")
        #expect(parts[0]["text"] as? String == "What is shown?")
        #expect(parts[1]["type"] as? String == "file")
        #expect(parts[1]["mime"] as? String == "image/png")
        #expect(parts[1]["filename"] as? String == "meowpal-screenshot.png")
        #expect(parts[1]["url"] as? String == "data:image/png;base64,abc123")
    }

    @Test func extractAssistantTextReturnsLastAssistantTextPart() {
        let messages: [[String: Any]] = [
            [
                "info": ["role": "user"],
                "parts": [["type": "text", "text": "hi"]]
            ],
            [
                "info": ["role": "assistant"],
                "parts": [
                    ["type": "text", "text": "Hello"],
                    ["type": "text", "text": " there"]
                ]
            ]
        ]

        #expect(OpenCodeClient.extractLatestAssistantText(from: messages) == "Hello there")
    }
}
