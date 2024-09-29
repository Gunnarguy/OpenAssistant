import SwiftUI

struct AssistantDetailsSection: View {
    @Binding var assistant: Assistant
    var availableModels: [String]

    var body: some View {
        Section(header: Text("Assistant Details")) {
            nameField
            instructionsField
            modelPicker
            descriptionField
            temperatureSlider
            topPSlider
        }
    }

    private var nameField: some View {
        TextField("Name", text: $assistant.name)
    }

    private var instructionsField: some View {
        TextField("Instructions", text: Binding($assistant.instructions, default: ""))
    }

    private var descriptionField: some View {
        TextField("Description", text: Binding($assistant.description, default: ""))
    }

    private var modelPicker: some View {
        Picker("Model", selection: $assistant.model) {
            ForEach(availableModels, id: \.self) { model in
                Text(model).tag(model)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }

    private var temperatureSlider: some View {
        VStack {
            Text("Temperature: \(assistant.temperature, specifier: "%.2f")")
            Slider(value: $assistant.temperature, in: 0.0...2.0, step: 0.01)
        }
    }

    private var topPSlider: some View {
        VStack {
            Text("Top P: \(assistant.top_p, specifier: "%.2f")")
            Slider(value: $assistant.top_p, in: 0.0...1.0, step: 0.01)
        }
    }
}
