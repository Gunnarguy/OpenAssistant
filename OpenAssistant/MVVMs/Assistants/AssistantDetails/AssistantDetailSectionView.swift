import Combine
import SwiftUI

struct AssistantDetailsSection: View {
    @Binding var assistant: Assistant
    var availableModels: [String]

    // State to track the original model type (O-series or GPT-series)
    @State private var originalModelIsOseries: Bool = false

    // Available reasoning effort options for display
    private let reasoningOptions = ["low", "medium", "high"]

    // Helper to check if the *current* selection is an O-series model
    private var isCurrentSelectionOModel: Bool {
        // Use the static method from BaseViewModel for consistency
        return BaseViewModel.isReasoningModel(assistant.model)
    }

    // Filtered list of models based on the original assistant's model type
    private var filteredAvailableModels: [String] {
        availableModels.filter { modelId in
            let isModelOseries = BaseViewModel.isReasoningModel(modelId)
            // Show only models of the same type as the original
            return isModelOseries == originalModelIsOseries
        }
    }

    var body: some View {
        Section(header: Text("Assistant Details")) {
            // Display Name (Editable)
            NameField(name: $assistant.name)
            // Instructions (Editable)
            InstructionsField(instructions: Binding($assistant.instructions, default: ""))

            // Model Picker - Filtered based on original model type
            Picker("Model", selection: $assistant.model) {
                // Iterate over the filtered list
                ForEach(filteredAvailableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            // Add info text explaining the restriction
            Text("Model cannot be changed between GPT and O-series families after creation.")
                .font(.caption)
                .foregroundColor(.secondary)

            // Description (Editable)
            DescriptionField(description: Binding($assistant.description, default: ""))

            // Conditional UI based on *current* model selection type
            if isCurrentSelectionOModel {
                // Reasoning Effort Picker for O-series models
                Picker("Reasoning Effort", selection: $assistant.reasoning_effort) {
                    Text("Default (medium)").tag(nil as String?)  // Option for default
                    ForEach(reasoningOptions, id: \.self) { effort in
                        Text(effort.capitalized).tag(effort as String?)  // Use optional tag
                    }
                }
            } else {
                // Temperature Slider for non-O models
                VStack(alignment: .leading) {
                    Text("Temperature: \(assistant.temperature, specifier: "%.2f")")
                    Slider(value: $assistant.temperature, in: 0.0...2.0, step: 0.1)
                }

                // Top P Slider for non-O models
                VStack(alignment: .leading) {
                    Text("Top P: \(assistant.top_p, specifier: "%.2f")")
                    Slider(value: $assistant.top_p, in: 0.0...1.0, step: 0.1)
                }
            }
        }
        .onAppear {
            // Determine the original model type when the view appears
            self.originalModelIsOseries = BaseViewModel.isReasoningModel(assistant.model)
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
