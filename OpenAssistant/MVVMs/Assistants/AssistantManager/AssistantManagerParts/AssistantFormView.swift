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
            // Section for core details
            Section(header: Text("Core Details")) {
                // Use HStacks for labels with icons and text fields
                HStack {
                    Image(systemName: "textformat.abc")
                        .foregroundColor(.secondary)
                    TextField("Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                    // Use TextEditor for potentially longer instructions
                    TextEditor(text: $instructions)
                        .frame(height: 100)  // Set a reasonable initial height
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))  // Add border
                }

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    // Use TextEditor for potentially longer descriptions
                    TextEditor(text: $description)
                        .frame(height: 60)  // Set a reasonable initial height
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))  // Add border
                }

                // Model Picker - Only enabled during creation
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.secondary)
                    modelPicker
                        .disabled(isEditing)  // Disable model changes after creation
                }
                // Add info text explaining the restriction if editing
                if isEditing {
                    Text(
                        "Model cannot be changed between GPT and O-series families after creation."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            // Section for Generation Parameters (Conditional)
            generationParametersSection

            // Section for Tools
            toolsSection

            // Section for Action Buttons
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

    // MARK: - Generation Parameters Section (Extracted)
    // Conditionally displays relevant parameters based on the selected model.
    @ViewBuilder  // Use ViewBuilder for conditional content
    private var generationParametersSection: some View {
        // Only show the section if there are parameters to display
        if BaseViewModel.isReasoningModel(model)
            || BaseViewModel.supportsTempTopPAtAssistantLevel(model)
        {
            Section(header: Text("Generation Settings")) {
                if BaseViewModel.isReasoningModel(model) {
                    // Reasoning Effort Picker
                    VStack(alignment: .leading) {
                        Label("Reasoning Effort", systemImage: "brain.head.profile")
                        Picker("Reasoning Effort", selection: $reasoningEffort) {
                            ForEach(reasoningOptions, id: \.self) { effort in
                                Text(effort.capitalized).tag(effort)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        Text("Affects model behavior (cost, latency, performance).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)  // Add padding

                } else if BaseViewModel.supportsTempTopPAtAssistantLevel(model) {
                    // Temperature Slider
                    TemperatureSlider(temperature: $temperature)
                        .padding(.vertical, 4)  // Add vertical padding
                    // Top P Slider
                    TopPSlider(topP: $topP)
                        .padding(.vertical, 4)  // Add vertical padding
                }
            }
        }
        // Implicitly returns EmptyView if conditions are not met
    }

    // MARK: - Tools Section
    // Toggles to enable or disable built-in assistant tools.
    private var toolsSection: some View {
        Section(header: Text("Capabilities")) {  // Renamed header for clarity
            Toggle(isOn: $enableFileSearch) {
                Label("Enable File Search", systemImage: "doc.text.magnifyingglass")
            }
            Toggle(isOn: $enableCodeInterpreter) {
                Label("Enable Code Interpreter", systemImage: "curlybraces.square")
            }
        }
    }

    // MARK: - Action Buttons
    // Save or update assistant, with optional delete action when editing
    private var actionButtons: some View {
        Section {
            HStack {
                Spacer()
                // Save/Update Button with Icon
                Button {
                    onSave()
                } label: {
                    Label(isEditing ? "Update" : "Save", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                // Delete Button with Icon (if editing)
                if isEditing, let onDelete = onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                Spacer()
            }
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Model Picker
    // Dropdown menu to select available model
    private var modelPicker: some View {
        Picker("Model", selection: $model) {
            // Let user pick any available model.
            ForEach(availableModels, id: \.self) { modelId in
                Text(modelId).tag(modelId)
            }
        }
        .pickerStyle(MenuPickerStyle())
        // The .disabled(isEditing) modifier is applied higher up where modelPicker is used.
    }
}

// MARK: - TemperatureSlider
/// Slider view for adjusting generation temperature (0.0...2.0)
private struct TemperatureSlider: View {
    @Binding var temperature: Double

    var body: some View {
        VStack(alignment: .leading) {
            // Use Label for consistency
            Label(
                "Temperature: \(temperature, specifier: "%.2f")",
                systemImage: "thermometer.medium"
            )
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
            // Use Label for consistency
            Label("Top P: \(topP, specifier: "%.2f")", systemImage: "chart.pie")
            Slider(value: $topP, in: 0.0...1.0, step: 0.01)
        }
    }
}

// MARK: - Preview
struct AssistantFormView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Create Mode Preview
            NavigationView {
                AssistantFormView(
                    name: .constant("Sample Assistant"),
                    instructions: .constant("These are example instructions."),
                    model: .constant("gpt-3.5-turbo"),
                    description: .constant("An example assistant description."),
                    temperature: .constant(1.0),
                    topP: .constant(1.0),
                    reasoningEffort: .constant("medium"),
                    enableFileSearch: .constant(true),
                    enableCodeInterpreter: .constant(false),
                    availableModels: ["gpt-3.5-turbo", "gpt-4", "o1"],
                    isEditing: false,
                    onSave: {},
                    onDelete: nil
                )
                .navigationTitle("Create Assistant")
            }
            .previewDisplayName("Create Mode")

            // Edit Mode Preview
            NavigationView {
                AssistantFormView(
                    name: .constant("Existing Assistant"),
                    instructions: .constant("Updated instructions for an existing assistant."),
                    model: .constant("o1"),
                    description: .constant("This assistant already exists and is being edited."),
                    temperature: .constant(1.0),
                    topP: .constant(1.0),
                    reasoningEffort: .constant("high"),
                    enableFileSearch: .constant(false),
                    enableCodeInterpreter: .constant(true),
                    availableModels: ["gpt-3.5-turbo", "gpt-4", "o1"],
                    isEditing: true,
                    onSave: {},
                    onDelete: {}
                )
                .navigationTitle("Edit Assistant")
                .preferredColorScheme(.dark)
            }
            .previewDisplayName("Edit Mode (Dark)")
        }
    }
}
