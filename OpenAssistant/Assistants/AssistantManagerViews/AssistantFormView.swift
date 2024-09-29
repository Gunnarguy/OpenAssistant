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
            Section(header: Text("Assistant Details")) {
                TextField("Name", text: $name)
                TextField("Instructions", text: $instructions)
                Picker("Model", selection: $model) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                TextField("Description", text: $description)
                temperatureSlider
                topPSlider
            }

            Section(header: Text("Tools")) {
                Toggle("Enable File Search", isOn: $enableFileSearch)
                Toggle("Enable Code Interpreter", isOn: $enableCodeInterpreter)
            }

            actionButtons
        }
    }

    private var temperatureSlider: some View {
        VStack {
            Text("Temperature: \(temperature, specifier: "%.2f")")
            Slider(value: $temperature, in: 0.0...2.0, step: 0.01)
        }
    }

    private var topPSlider: some View {
        VStack {
            Text("Top P: \(topP, specifier: "%.2f")")
            Slider(value: $topP, in: 0.0...1.0, step: 0.01)
        }
    }

    private var actionButtons: some View {
        HStack {
            Button(isEditing ? "Update" : "Save", action: onSave)
                .foregroundColor(.blue)
            if isEditing, let onDelete = onDelete {
                Button("Delete", action: onDelete)
                    .foregroundColor(.red)
            }
        }
    }
}

