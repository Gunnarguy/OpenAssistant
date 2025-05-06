import Combine
import Foundation
import SwiftUI

struct AssistantDetailsSection: View {
    @Binding var assistant: Assistant
    var availableModels: [String]

    // State to track the original model type (O-series or GPT-series)
    @State private var originalModelIsOseries: Bool = false
    @State private var originalModelIs4o: Bool = false

    // Available reasoning effort options for display
    private let reasoningOptions = ["low", "medium", "high"]

    // Helper to check if the *current* selection is an O-series model
    private var isCurrentSelectionOModel: Bool {
        // Use the static method from BaseViewModel for consistency
        return BaseViewModel.isReasoningModel(assistant.model)
    }

    // Helper to check if the current selection is a 4o model
    private var isCurrentSelection4oModel: Bool {
        return assistant.model.contains("4o")
    }

    // Filtered list of models based on the original assistant's model type
    private var filteredAvailableModels: [String] {
        availableModels.filter { modelId in
            // Check if the model is an O-series model
            let isModelOseries = BaseViewModel.isReasoningModel(modelId)
            // Check if the model is a 4o model family
            let isModel4o = modelId.contains("4o")

            if originalModelIsOseries {
                // If original model was O-series, only show O-series models
                return isModelOseries
            } else if originalModelIs4o {
                // If original model was 4o, only show 4o models
                return isModel4o
            } else {
                // For other models like GPT-4, GPT-3.5, show models in same family (non-O, non-4o)
                return !isModelOseries && !isModel4o
            }
        }
    }

    var body: some View {
        Section(header: Text("Core Details")) {  // Consistent header
            // Display Name (Editable) - Use HStack with icon
            HStack {
                Image(systemName: "textformat.abc")
                    .foregroundColor(.secondary)
                NameField(name: $assistant.name)
            }

            // Instructions (Editable) - Use HStack with icon and TextEditor
            HStack(alignment: .top) {  // Align icon to top
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                    .padding(.top, 8)  // Adjust icon position slightly
                InstructionsField(instructions: Binding($assistant.instructions, default: ""))
            }

            // Model Picker - Filtered based on original model type - Use HStack with icon
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.secondary)
                // Only show available models of the same family
                if !filteredAvailableModels.isEmpty {
                    Picker("Model", selection: $assistant.model) {
                        ForEach(filteredAvailableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                } else {
                    Text("No compatible models available")
                        .foregroundColor(.secondary)
                }
            }

            // Info text explaining the model restriction
            if originalModelIsOseries {
                Text("O-series models can only be updated to other O-series models")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if originalModelIs4o {
                Text("GPT-4o models can only be updated to other GPT-4o models")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Model family cannot be changed after creation")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Description (Editable) - Use HStack with icon and TextEditor
            HStack(alignment: .top) {  // Align icon to top
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .padding(.top, 8)  // Adjust icon position slightly
                DescriptionField(description: Binding($assistant.description, default: ""))
            }
        }
        .onAppear {
            self.originalModelIsOseries = BaseViewModel.isReasoningModel(assistant.model)
            self.originalModelIs4o = assistant.model.contains("4o")
        }

        // Section for Generation Parameters (Conditional) - Extracted for clarity
        generationParametersSection
    }

    // MARK: - Generation Parameters Section (Extracted)
    @ViewBuilder
    private var generationParametersSection: some View {
        // Only show the section if there are parameters to display
        if isCurrentSelectionOModel
            || BaseViewModel.supportsTempTopPAtAssistantLevel(assistant.model)
        {
            Section(header: Text("Generation Settings")) {  // Consistent header
                if isCurrentSelectionOModel {
                    // Reasoning Effort Picker
                    VStack(alignment: .leading) {
                        Label("Reasoning Effort", systemImage: "brain.head.profile")
                        Picker("Reasoning Effort", selection: $assistant.reasoning_effort) {
                            Text("Default (medium)").tag(nil as String?)
                            ForEach(reasoningOptions, id: \.self) { effort in
                                Text(effort.capitalized).tag(effort as String?)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        Text("Affects model behavior (cost, latency, performance).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                } else {
                    // Temperature Slider
                    VStack(alignment: .leading) {
                        Label(
                            "Temperature: \(assistant.temperature, specifier: "%.2f")",
                            systemImage: "thermometer.medium"
                        )
                        Slider(value: $assistant.temperature, in: 0.0...2.0, step: 0.1)
                    }
                    .padding(.vertical, 4)

                    // Top P Slider
                    VStack(alignment: .leading) {
                        Label(
                            "Top P: \(assistant.top_p, specifier: "%.2f")", systemImage: "chart.pie"
                        )
                        Slider(value: $assistant.top_p, in: 0.0...1.0, step: 0.1)
                    }
                    .padding(.vertical, 4)
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
        // Use TextEditor for consistency and better multi-line editing
        TextEditor(text: $instructions)
            .frame(height: 100)  // Set a reasonable initial height
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))  // Add border
    }
}

private struct DescriptionField: View {
    @Binding var description: String

    var body: some View {
        // Use TextEditor for consistency
        TextEditor(text: $description)
            .frame(height: 60)  // Set a reasonable initial height
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))  // Add border
    }
}

// Remove slider definitions if they are handled by AssistantFormView's definitions
// ...

// MARK: - Extensions

extension Binding where Value == String {
    fileprivate init(_ source: Binding<String?>, default defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0 }
        )
    }
}

// MARK: - Previews
struct AssistantDetailsSection_Previews: PreviewProvider {
    @State static var previewAssistant = Assistant(
        id: "preview-1",
        object: "assistant",
        created_at: Int(Date().timeIntervalSince1970),
        name: "Preview Assistant",
        description: "This is a preview assistant for testing.",
        model: "gpt-3.5-turbo",
        instructions: "You are a helpful assistant for demonstration purposes.",
        tools: [],
        top_p: 0.8,
        temperature: 0.7
    )

    static var previews: some View {
        NavigationView {
            Form {
                AssistantDetailsSection(
                    assistant: $previewAssistant,
                    availableModels: ["gpt-3.5-turbo", "gpt-4", "gpt-4o", "o1-mini", "o1"]
                )
            }
            .navigationTitle("Assistant Details")
        }
    }
}
