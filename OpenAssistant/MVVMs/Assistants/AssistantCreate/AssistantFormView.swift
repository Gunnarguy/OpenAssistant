import SwiftUI

// AssistantFormView: Form for creating or editing an Assistant
struct AssistantFormView: View {
    @Binding var name: String
    @Binding var instructions: String
    @Binding var model: String
    @Binding var description: String
    @Binding var temperature: Double
    @Binding var topP: Double
    @Binding var reasoningEffort: String  // effort level for reasoning models
    @Binding var enableFileSearch: Bool
    @Binding var enableCodeInterpreter: Bool
    var availableModels: [String]
    var isEditing: Bool
    var onSave: () -> Void
    var onDelete: (() -> Void)? = nil  // Optional delete action with default value

    // Available reasoning effort options
    private let reasoningOptions = ["low", "medium", "high"]

    var body: some View {
        Form {
            assistantDetailsSection
            toolsSection
            actionButtons
        }
        .onAppear {
            if model.isEmpty, let firstModel = availableModels.first {
                model = firstModel
            }
        }
        .onChange(of: availableModels) { models in
            if !models.contains(model), let firstModel = models.first {
                model = firstModel
            }
        }
    }

    // MARK: - Assistant Details Section
    // Contains fields for name, instructions, model selection, description, and optional generation parameters.
    private var assistantDetailsSection: some View {
        Section(header: Text("Assistant Details")) {
            TextField("Name", text: $name)  // Assistant display name
            TextField("Instructions", text: $instructions)  // System prompt instructions

            // Model Picker - Only enabled during creation
            modelPicker.disabled(isEditing)

            TextField("Description", text: $description)  // Short assistant description

            // Show reasoning controls ONLY for reasoning models during CREATION
            if BaseViewModel.isReasoningModel(model) {
                Picker("Reasoning Effort", selection: $reasoningEffort) {
                    ForEach(reasoningOptions, id: \.self) { effort in
                        Text(effort.capitalized).tag(effort)
                    }
                }
                .disabled(isEditing)  // Disable if editing (redundant but safe)
                .pickerStyle(SegmentedPickerStyle())

                Text(
                    "Reasoning effort affects model behavior (cost, latency, performance). Set at creation."
                )
                .font(.caption)
                .foregroundColor(.secondary)

                // Show hint if editing (though picker is disabled)
                if isEditing {
                    Text("Model and reasoning effort can only be set at creation time.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            } else if BaseViewModel.supportsTempTopPAtAssistantLevel(model) {
                // Show Temp/TopP controls ONLY for non-reasoning models during CREATION
                Text("Generation Parameters (Set at creation):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TemperatureSlider(temperature: $temperature)
                    .disabled(isEditing)  // Disable if editing
                TopPSlider(topP: $topP)
                    .disabled(isEditing)  // Disable if editing

                // Show hint if editing (though sliders are disabled)
                if isEditing {
                    Text("Model, Temperature, and Top-P can only be set at creation time.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            // No controls shown if model supports neither at assistant level
        }
    }

    // MARK: - Tools Section
    // Toggles to enable or disable built-in assistant tools
    private var toolsSection: some View {
        Section(header: Text("Tools")) {
            Toggle("Enable File Search", isOn: $enableFileSearch)
            Toggle("Enable Code Interpreter", isOn: $enableCodeInterpreter)
        }
    }

    // MARK: - Action Buttons
    // Save or update assistant, with optional delete action when editing
    private var actionButtons: some View {
        HStack {
            Button(isEditing ? "Update" : "Save", action: onSave)
                .foregroundColor(.blue)
            if isEditing, let onDelete = onDelete {
                Button("Delete", action: onDelete)
                    .foregroundColor(.red)
            }
        }
        .buttonStyle(BorderlessButtonStyle())  // Keeps buttons styled in form context
    }

    // MARK: - Model Picker
    // Dropdown menu to select available model
    private var modelPicker: some View {
        Picker("Model", selection: $model) {
            // Filter available models based on whether they are reasoning models or support temp/top_p
            // Let user pick any available model during creation.
            ForEach(availableModels, id: \.self) { modelId in
                Text(modelId).tag(modelId)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }
}

// MARK: - TemperatureSlider
/// Slider view for adjusting generation temperature (0.0...2.0)
private struct TemperatureSlider: View {
    @Binding var temperature: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text("Temperature: \(temperature, specifier: "%.2f")")
            Slider(value: $temperature, in: 0.0...2.0, step: 0.01)
        }
    }
}

// MARK: - TopPSlider
/// Slider view for adjusting generation Top-P (0.0...1.0)
private struct TopPSlider: View {
    @Binding var topP: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text("Top P: \(topP, specifier: "%.2f")")
            Slider(value: $topP, in: 0.0...1.0, step: 0.01)
        }
    }
}
