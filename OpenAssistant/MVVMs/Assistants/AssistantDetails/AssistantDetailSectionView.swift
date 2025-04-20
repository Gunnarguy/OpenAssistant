import Combine
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
            // Show reasoning controls only for reasoning models
            if BaseViewModel.isReasoningModel(assistant.model) {
                Text("Reasoning adjustments (affects creativity and determinism):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TemperatureSlider(temperature: $assistant.temperature)
                TopPSlider(topP: $assistant.top_p)
            }
        }
<<<<<<< HEAD
=======
        // Re-evaluate this section when model changes
        .id(assistant.model)
        .animation(.default, value: assistant.model)
        // Debug: log model change in details
        .onChange(of: assistant.model) { newModel in
            print("AssistantDetailSection: model changed to \(newModel)")
        }
>>>>>>> f4401e5 (Add release configuration, fix App Store rejection issues, and update documentation)
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
