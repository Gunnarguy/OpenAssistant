import SwiftUI

// AssistantFormView: Form for creating or editing an Assistant
struct AssistantFormView: View {
    @Binding var name: String
    @Binding var instructions: String
    @Binding var model: String
    @Binding var description: String
    @Binding var temperature: Double
    @Binding var topP: Double
    @Binding var enableFileSearch: Bool
    @Binding var enableCodeInterpreter: Bool
    var availableModels: [String]
    var isEditing: Bool
    var onSave: () -> Void
    var onDelete: (() -> Void)?  // Optional delete action

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
            // Disable model picker if editing an existing assistant
            modelPicker.disabled(isEditing)
            TextField("Description", text: $description)  // Short assistant description

            // Show reasoning controls only for reasoning models
            if BaseViewModel.modelSupportsGenerationParameters(model) {
                Text("Reasoning adjustments (affects creativity and determinism):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                // Disable sliders if editing an existing assistant
                TemperatureSlider(temperature: $temperature)
                    .disabled(isEditing)
                TopPSlider(topP: $topP)
                    .disabled(isEditing)
                // Show a hint if editing
                if isEditing {
                    Text("Model and reasoning settings can only be set at creation time for reasoning models.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
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
            ForEach(availableModels, id: \.self) { model in
                Text(model).tag(model)
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
