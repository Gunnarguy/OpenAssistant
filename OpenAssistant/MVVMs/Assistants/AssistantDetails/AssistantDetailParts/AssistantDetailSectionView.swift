import Combine
import Foundation
import SwiftUI

struct AssistantDetailsSection: View {
    @Binding var assistant: Assistant
    var availableModels: [String]

    // Optional view model reference to trigger UI updates when bindings change
    weak var viewModel: AssistantDetailViewModel?

    // State to track the original model type
    @State private var originalModelIsOseries: Bool = false
    @State private var originalModelIs4oFamily: Bool = false  // Renamed from originalModelIs4o
    @State private var originalModelIs4point1Family: Bool = false  // New state variable

    // Available reasoning effort options for display
    private let reasoningOptions = ["low", "medium", "high"]

    // Custom binding for name that triggers view model updates
    private var nameBinding: Binding<String> {
        Binding(
            get: { assistant.name },
            set: { newValue in
                assistant.name = newValue
                // Trigger view model update if available
                viewModel?.objectWillChange.send()
            }
        )
    }

    // Custom binding for model that triggers view model updates
    private var modelBinding: Binding<String> {
        Binding(
            get: { assistant.model },
            set: { newValue in
                assistant.model = newValue
                // Trigger view model update if available
                viewModel?.objectWillChange.send()
            }
        )
    }

    // Custom binding for instructions that triggers view model updates
    private var instructionsBinding: Binding<String> {
        Binding(
            get: { assistant.instructions ?? "" },
            set: { newValue in
                assistant.instructions = newValue.isEmpty ? nil : newValue
                // Trigger view model update if available
                viewModel?.objectWillChange.send()
            }
        )
    }

    // Custom binding for description that triggers view model updates
    private var descriptionBinding: Binding<String> {
        Binding(
            get: { assistant.description ?? "" },
            set: { newValue in
                assistant.description = newValue.isEmpty ? nil : newValue
                // Trigger view model update if available
                viewModel?.objectWillChange.send()
            }
        )
    }

    // Custom binding for reasoning effort that triggers view model updates
    private var reasoningEffortBinding: Binding<String?> {
        Binding(
            get: { assistant.reasoning_effort },
            set: { newValue in
                assistant.reasoning_effort = newValue
                // Trigger view model update if available
                viewModel?.objectWillChange.send()
                print("AssistantDetailsSection: reasoning_effort changed to \(newValue ?? "nil")")
            }
        )
    }

    // Helper to check if the *current* selection is an O-series model
    private var isCurrentSelectionOModel: Bool {
        return BaseViewModel.isReasoningModel(assistant.model)
    }

    // Helper function to check if a model ID belongs to the GPT-4o family
    private func is4oFamily(_ modelId: String) -> Bool {
        return modelId.lowercased().contains("gpt-4o")
    }

    // Helper function to check if a model ID belongs to the GPT-4.1 family
    private func is4point1Family(_ modelId: String) -> Bool {
        return modelId.lowercased().contains("gpt-4.1")
    }

    // Filtered list of models based on the original assistant's model type
    private var filteredAvailableModels: [String] {
        availableModels.filter { modelId in
            let modelIsOseries = BaseViewModel.isReasoningModel(modelId)
            let modelIs4o = is4oFamily(modelId)
            let modelIs4point1 = is4point1Family(modelId)

            if originalModelIsOseries {
                // If original model was O-series, only show O-series models
                return modelIsOseries
            } else if originalModelIs4oFamily || originalModelIs4point1Family {
                // If original model was from 4o or 4.1 family, allow interchange between these two families
                return modelIs4o || modelIs4point1
            } else {
                // For other models (e.g., GPT-4 legacy, GPT-3.5),
                // show models that are NOT O-series, NOT 4o-family, and NOT 4.1-family
                return !modelIsOseries && !modelIs4o && !modelIs4point1
            }
        }
    }

    var body: some View {
        Section(header: Text("Core Details")) {  // Consistent header
            // Display Name (Editable) - Use HStack with icon
            HStack {
                Image(systemName: "textformat.abc")
                    .foregroundColor(.secondary)
                NameField(name: nameBinding)
            }

            // Instructions (Editable) - Use HStack with icon and TextEditor
            HStack(alignment: .top) {  // Align icon to top
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                    .padding(.top, 8)  // Adjust icon position slightly
                InstructionsField(instructions: instructionsBinding)
            }

            // Model Picker - Filtered based on original model type - Use HStack with icon
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.secondary)
                // Only show available models of the same family
                if !filteredAvailableModels.isEmpty {
                    Picker("Model", selection: modelBinding) {
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
                Text("O-series models can only be updated to other O-series models.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if originalModelIs4oFamily || originalModelIs4point1Family {
                Text("GPT-4o and GPT-4.1 family models can be interchanged.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Model family (e.g., GPT-3.5, older GPT-4) cannot be changed after creation.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Description (Editable) - Use HStack with icon and TextEditor
            HStack(alignment: .top) {  // Align icon to top
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .padding(.top, 8)  // Adjust icon position slightly
                DescriptionField(description: descriptionBinding)
            }
        }
        .onAppear {
            self.originalModelIsOseries = BaseViewModel.isReasoningModel(assistant.model)
            self.originalModelIs4oFamily = is4oFamily(assistant.model)  // Updated to use helper
            self.originalModelIs4point1Family = is4point1Family(assistant.model)  // Initialize new state
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
                        Picker("Reasoning Effort", selection: reasoningEffortBinding) {
                            ForEach(reasoningOptions, id: \.self) { effort in
                                Text(effort.capitalized).tag(effort as String?)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        Text(
                            "Medium is default. Affects model behavior (cost, latency, performance)."
                        )
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
                        Slider(value: $assistant.temperature, in: 0.0...2.0)
                    }
                    .padding(.vertical, 4)

                    // Top P Slider
                    VStack(alignment: .leading) {
                        Label(
                            "Top P: \(assistant.top_p, specifier: "%.2f")", systemImage: "chart.pie"
                        )
                        Slider(value: $assistant.top_p, in: 0.0...1.0)
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
                    availableModels: ["gpt-3.5-turbo", "gpt-4", "gpt-4o", "o1-mini", "o1"],
                    viewModel: nil
                )
            }
            .navigationTitle("Assistant Details")
        }
    }
}
