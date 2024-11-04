import SwiftUI

struct AssistantDetailsSection: View {
    @Binding var assistant: Assistant
    var availableModels: [String]

    var body: some View {
        Section(header: Text("Assistant Details")) {
            NameField(name: $assistant.name)
            InstructionsField(instructions: Binding($assistant.instructions, default: ""))
            ModelPicker(model: $assistant.model, availableModels: availableModels)
            DescriptionField(description: Binding($assistant.description, default: ""))
            TemperatureSlider(temperature: $assistant.temperature)
            TopPSlider(topP: $assistant.top_p)
        }
    }
}

// MARK: - Subviews

private struct NameField: View {
    @Binding var name: String

    var body: some View {
        TextField("Name", text: $name)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.vertical, 4)
    }
}

private struct InstructionsField: View {
    @Binding var instructions: String

    var body: some View {
        TextField("Instructions", text: $instructions)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.vertical, 4)
    }
}

private struct DescriptionField: View {
    @Binding var description: String

    var body: some View {
        TextField("Description", text: $description)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.vertical, 4)
    }
}

struct ModelPicker: View {
    @Binding var model: String
    var availableModels: [String]

    var body: some View {
        Picker("Model", selection: $model) {
            ForEach(availableModels, id: \.self) { model in
                Text(model).tag(model)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .padding(.vertical, 4)
    }
}

private struct TemperatureSlider: View {
    @Binding var temperature: Double

    var body: some View {
        VStack {
            Text("Temperature: \(temperature, specifier: "%.2f")")
            Slider(value: $temperature, in: 0.0...2.0, step: 0.01)
        }
        .padding(.vertical, 4)
    }
}

private struct TopPSlider: View {
    @Binding var topP: Double

    var body: some View {
        VStack {
            Text("Top P: \(topP, specifier: "%.2f")")
            Slider(value: $topP, in: 0.0...1.0, step: 0.01)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Extensions

private extension Binding where Value == String {
    init(_ source: Binding<String?>, default defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0 }
        )
    }
}
