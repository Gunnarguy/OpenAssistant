// ModelCapabilities.swift
// Centralized model capability logic for OpenAI models

import Foundation

/// Centralized helper for model capability checks.
public struct ModelCapabilities {
    /// Returns true if the model supports temperature/top_p at the assistant level.
    public static func supportsTempTopPAtAssistantLevel(_ modelId: String) -> Bool {
        // Reasoning models (o-series) do NOT support temp/top_p at the assistant level.
        let reasoningPrefixes = ["o1", "o3", "o4"]
        for prefix in reasoningPrefixes {
            if modelId.lowercased().starts(with: prefix) {
                return false  // Reasoning models use reasoning_effort
            }
        }
        // Assume other models (like gpt-*) DO support temp/top_p.
        return true
    }
}
