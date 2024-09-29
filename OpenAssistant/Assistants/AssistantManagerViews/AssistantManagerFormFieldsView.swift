import Foundation
import SwiftUI
import Combine

struct FormFieldsView: View {
    @Binding var assistant: Assistant
    @ObservedObject var viewModel: AssistantManagerViewModel

    var body: some View {
        Form {
            basicInformationSection
        }
    }

    private var basicInformationSection: some View {
        Section(header: Text("Basic Information")) {
            TextField("Name", text: $assistant.name)
                .onChange(of: assistant.name) { newValue in
                    updateAssistant()
                }
            TextField("Instructions", text: Binding($assistant.instructions, default: ""))
                .onChange(of: assistant.instructions) { newValue in
                    updateAssistant()
                }
            modelPicker
            TextField("Description", text: Binding($assistant.description, default: ""))
                .onChange(of: assistant.description) { newValue in
                    updateAssistant()
                }
        }
    }

    private var modelPicker: some View {
        Picker("Model", selection: $assistant.model) {
            ForEach(viewModel.availableModels, id: \.self) { model in
                Text(model).tag(model)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .onChange(of: assistant.model) { newModel in
            updateAssistant()
        }
    }

    private func updateAssistant() {
        NotificationCenter.default.post(name: .assistantUpdated, object: assistant)
    }
}

struct SlidersView: View {
    @Binding var assistant: Assistant

    var body: some View {
        VStack {
            temperatureSlider
            topPSlider
        }
    }

    private var temperatureSlider: some View {
        HStack {
            Text("Temperature: \(assistant.temperature, specifier: "%.2f")")
            Slider(value: $assistant.temperature, in: 0...2, step: 0.1)
                .onChange(of: assistant.temperature) { newValue in
                    updateAssistant()
                }
        }
        .padding()
    }

    private var topPSlider: some View {
        HStack {
            Text("Top P: \(assistant.top_p, specifier: "%.2f")")
            Slider(value: $assistant.top_p, in: 0...1, step: 0.1)
                .onChange(of: assistant.top_p) { newValue in
                    updateAssistant()
                }
        }
        .padding()
    }

    private func updateAssistant() {
        NotificationCenter.default.post(name: .assistantUpdated, object: assistant)
    }
}

struct ActionButtonsView: View {
    @Binding var refreshTrigger: Bool
    var updateAction: () -> Void
    var deleteAction: () -> Void
    var createVectorStoreAction: (() -> Void)? = nil // Make it optional

    var body: some View {
        VStack {
            Button("Update", action: updateAction)
            Button("Delete", action: deleteAction)
            if let createAction = createVectorStoreAction {
                Button("Create Vector Store", action: createAction)
            }
        }
    }
}
