import Foundation

// MARK: - Model Parameter Support Helper

/// Checks if a given model identifier typically supports temperature/top_p settings for generation.
/// Note: Assistants API itself doesn't use these during creation/update.
func modelSupportsGenerationParameters(_ modelId: String) -> Bool {
    // Models known *not* to typically use these for standard chat/completion endpoints
    // or where they are less relevant in the Assistants context.
    let unsupportedPrefixes = [
        "o1", "o3", "o4", "dall-e", "whisper", "tts", "text-embedding", "babbage", "davinci",
        "omni-moderation", "computer-use",
    ]

    for prefix in unsupportedPrefixes {
        if modelId.starts(with: prefix) {
            return false
        }
    }
    // Assume supported for others (like gpt-4, gpt-3.5-turbo, etc.)
    return true
}
