import Foundation

// MARK: - Model Parameter Support Helper

/// Checks if a given model identifier supports temperature/top_p settings for generation
/// at the Assistant level. Reasoning models (o-series) use reasoning_effort instead.
// This function is removed as the logic is now localized within OpenAIService
/*
func modelSupportsTemperatureTopPAtAssistantLevel(_ modelId: String) -> Bool {
    // Reasoning models (o-series) do NOT support temp/top_p at the assistant level.
    let reasoningPrefixes = ["o1", "o3", "o4"]

    for prefix in reasoningPrefixes {
        if modelId.lowercased().starts(with: prefix) {
            return false // Reasoning models use reasoning_effort
        }
    }
    // Assume other models (like gpt-*) DO support temp/top_p.
    return true
}
*/
