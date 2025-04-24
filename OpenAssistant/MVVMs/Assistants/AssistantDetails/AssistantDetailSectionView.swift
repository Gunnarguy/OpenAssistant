import Combine
import SwiftUI

struct AssistantDetailsSection: View {
    @Binding var assistant: Assistant
    var availableModels: [String]

    // Available reasoning effort options for display
    private let reasoningOptions = ["low", "medium", "high"]

    // Helper to check if the current model is an O-series model
    private var isOModel: Bool {
        let modelId = assistant.model.lowercased()
        // Define prefixes for O-series models that use reasoning_effort
        let oPrefixes = ["o1", "o3", "o4"]
        return oPrefixes.contains { modelId.starts(with: $0) }
    }

    var body: some View {
        Section(header: Text("Assistant Details")) {
            // Display Name (Editable)
            NameField(name: $assistant.name)
            // Instructions (Editable)
            InstructionsField(instructions: Binding($assistant.instructions, default: ""))

            // Model Picker
            Picker("Model", selection: $assistant.model) {
                ForEach(availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }

            // Description (Editable)
            DescriptionField(description: Binding($assistant.description, default: ""))

            // Conditional UI based on model type
            if isOModel {
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
