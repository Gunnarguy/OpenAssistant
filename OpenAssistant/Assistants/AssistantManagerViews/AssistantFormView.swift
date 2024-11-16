import SwiftUI

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
    var onDelete: (() -> Void)? // Optional delete action

    var body: some View {
        Form {
            assistantDetailsSection
            //toolsSection
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

    // Assistant details section with model selection, temperature, and topP settings
    private var assistantDetailsSection: some View {
        Section(header: Text("Assistant Details")) {
            TextField("Name", text: $name)
            TextField("Instructions", text: $instructions)
            modelPicker
            TextField("Description", text: $description)
            TemperatureSlider(temperature: $temperature)
            TopPSlider(topP: $topP)
        }
    }

    // Section for enabling additional tools
    private var toolsSection: some View {
        Section(header: Text("Tools")) {
            Toggle("Enable File Search", isOn: $enableFileSearch)
            Toggle("Enable Code Interpreter", isOn: $enableCodeInterpreter)
        }
    }

    // Model selection picker using a dropdown menu style
    private var modelPicker: some View {
        Picker("Model", selection: $model) {
            ForEach(availableModels, id: \.self) { model in
                Text(model).tag(model)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }

    // Action buttons with conditional rendering for Save/Update and Delete
    private var actionButtons: some View {
        HStack {
            Button(isEditing ? "Update" : "Save", action: onSave)
                .foregroundColor(.blue)
            if isEditing, let onDelete = onDelete {
                Button("Delete", action: onDelete)
                    .foregroundColor(.red)
            }
        }
        .buttonStyle(BorderlessButtonStyle()) // Keeps buttons styled in form context
    }
}

// Slider for adjusting temperature with finer control and label
private struct TemperatureSlider: View {
    @Binding var temperature: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text("Temperature: \(temperature, specifier: "%.2f")")
            Slider(value: $temperature, in: 0.0...2.0, step: 0.01)
        }
    }
}

// Slider for adjusting topP with finer control and label
private struct TopPSlider: View {
    @Binding var topP: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text("Top P: \(topP, specifier: "%.2f")")
            Slider(value: $topP, in: 0.0...1.0, step: 0.01)
        }
    }
}
