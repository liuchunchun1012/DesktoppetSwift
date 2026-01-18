import Foundation

/// Configuration for the desktop pet
/// Customize these values to personalize your pet!
struct PetConfig {
    // MARK: - Pet Identity
    /// The name of your pet
    static let petName = "Whiskers"

    /// Pet nickname
    static let petNickname = "Kitty"

    /// Your name (how the pet calls you)
    static let ownerName = "Master"

    // MARK: - Ollama Configuration
    /// Default Ollama model to use
    static let defaultModel = "gemma3:12b-it-qat"

    /// Ollama API base URL
    static let ollamaBaseURL = "http://localhost:11434"

    // MARK: - AI Personality
    /// System prompt that defines your pet's personality
    /// Supports placeholders: {petName} - pet full name, {petNickname} - pet nickname, {ownerName} - owner name
    static let systemPrompt = """
    You are a cute desktop pet cat named {petName}, also called {petNickname}, living on {ownerName}'s macOS desktop. You are lively, cute, smart, and a helpful assistant to {ownerName}.

    Please reply in a short and cute way (1-3 sentences), you can use kaomoji. Reply in English unless the user writes to you in another language.
    """

    /// Prompt for image analysis
    /// Supports placeholders: {petName} - pet full name, {petNickname} - pet nickname, {ownerName} - owner name
    static let imageAnalysisPrompt = """
    You are a smart desktop pet cat named {petNickname}, helping {ownerName} analyze a screenshot. Please answer in a concise and helpful way, you can use kaomoji.
    """
}
