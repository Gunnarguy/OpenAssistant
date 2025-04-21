import Combine
import SwiftUI

struct AssistantDetailsSection: View {
    @Binding var assistant: Assistant
    var availableModels: [String]

    // Available reasoning effort options for display
    private let reasoningOptions = ["low", "medium", "high"]

    var body: some View {
        Section(header: Text("Assistant Details")) {
            // Display Name (Editable)
            NameField(name: $assistant.name)
            // Instructions (Editable)
            InstructionsField(instructions: Binding($assistant.instructions, default: ""))

            // Model (Read-Only)
            HStack {
                Text("Model")
                Spacer()
                // Display the model name as read-only text
                Text(assistant.model)
                    .foregroundColor(.secondary)
            }

            // Description (Editable)
            DescriptionField(description: Binding($assistant.description, default: ""))

            // Conditionally show generation parameters based on model type (Read-Only)
            if BaseViewModel.isReasoningModel(assistant.model) {
                // Display Reasoning Effort for O-series models (read-only)
                HStack {
                    Text("Reasoning Effort")
                    Spacer()
                    Text(assistant.reasoning_effort?.capitalized ?? "Default")
                        .foregroundColor(.secondary)
                }
                // Clarify immutability
                Text("Reasoning settings are set at creation and cannot be updated.")
                    .font(.caption2)
                    .foregroundColor(.orange)
            } else if BaseViewModel.supportsTempTopPAtAssistantLevel(assistant.model) {
                // Display Temp/TopP for other models (read-only)
                Text("Generation Parameters (Read-Only)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                // Ensure sliders are explicitly disabled
                TemperatureSlider(temperature: $assistant.temperature)
                    .disabled(true)
                TopPSlider(topP: $assistant.top_p)
                    .disabled(true)
                // Clarify immutability
                Text(
                    "Temperature/Top-P are set at creation and cannot be updated on the assistant."
                )
                .font(.caption2)
                .foregroundColor(.orange)
            } else {
                // Model might not support any generation params at assistant level
                Text(
                    "This model does not use specific generation parameters at the assistant level."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Subviews

private struct NameField: View {
    @Binding var name: String

    var body: some View {
        TextField("Name", text: $name)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

private struct InstructionsField: View {
    @Binding var instructions: String

    var body: some View {
        TextField("Instructions", text: $instructions)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

private struct DescriptionField: View {
    @Binding var description: String

    var body: some View {
        TextField("Description", text: $description)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

private struct TemperatureSlider: View {
    @Binding var temperature: Double

    var body: some View {
        VStack {
            Text("Temperature: \(temperature, specifier: "%.2f")")
            Slider(value: $temperature, in: 0.0...2.0, step: 0.01)
        }
    }
}

private struct TopPSlider: View {
    @Binding var topP: Double

    var body: some View {
        VStack {
            Text("Top P: \(topP, specifier: "%.2f")")
            Slider(value: $topP, in: 0.0...1.0, step: 0.01)
        }
    }
}

// MARK: - Extensions

extension Binding where Value == String {
    fileprivate init(_ source: Binding<String?>, default defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0 }
        )
    }
}
