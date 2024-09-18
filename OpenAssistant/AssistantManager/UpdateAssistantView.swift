import Foundation
import Combine
import SwiftUI

struct UpdateAssistantView: View {
    @ObservedObject var viewModel: AssistantManagerViewModel
    @StateObject private var assistantDetailViewModel: AssistantDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false

    init(viewModel: AssistantManagerViewModel, assistant: Assistant) {
        self.viewModel = viewModel
        _assistantDetailViewModel = StateObject(wrappedValue: AssistantDetailViewModel(assistant: assistant))
    }

    var body: some View {
        NavigationView {
            Form {
                assistantDetailsSection
                toolsSection
            }
            .navigationTitle("Update Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { handleSave() }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Validation Error"), message: Text("Please fill in all required fields."), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // MARK: - Assistant Details Section
    private var assistantDetailsSection: some View {
        Section(header: Text("Assistant Details")) {
            TextField("Name", text: $assistantDetailViewModel.assistant.name)
            TextField("Instructions", text: Binding($assistantDetailViewModel.assistant.instructions, default: ""))
            modelPicker
            TextField("Description", text: Binding($assistantDetailViewModel.assistant.description, default: ""))
            temperatureSlider
            topPSlider
        }
    }
    
    private var modelPicker: some View {
        Picker("Model", selection: $assistantDetailViewModel.assistant.model) {
            ForEach(viewModel.availableModels, id: \.self) { model in
                Text(model).tag(model)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }
    
    // MARK: - Tools Section
    private var toolsSection: some View {
        Section(header: Text("Tools")) {
            toolToggle(isOn: Binding(
                get: { assistantDetailViewModel.assistant.tools.contains(where: { $0.type == "file_search" }) },
                set: { isEnabled in
                    updateToolState(isEnabled: isEnabled, type: "file_search")
                }
            ), label: "Enable File Search")
            
            toolToggle(isOn: Binding(
                get: { assistantDetailViewModel.assistant.tools.contains(where: { $0.type == "code_interpreter" }) },
                set: { isEnabled in
                    updateToolState(isEnabled: isEnabled, type: "code_interpreter")
                }
            ), label: "Enable Code Interpreter")
        }
    }
    
    private func toolToggle(isOn: Binding<Bool>, label: String) -> some View {
        Toggle(label, isOn: isOn)
    }
    
    private func updateToolState(isEnabled: Bool, type: String) {
        if isEnabled {
            if !assistantDetailViewModel.assistant.tools.contains(where: { $0.type == type }) {
                assistantDetailViewModel.assistant.tools.append(Tool(type: type))
            }
        } else {
            assistantDetailViewModel.assistant.tools.removeAll(where: { $0.type == type })
        }
    }
    
    // MARK: - Sliders
    private var temperatureSlider: some View {
        sliderView(value: $assistantDetailViewModel.assistant.temperature, range: 0.0...2.0, label: "Temperature")
    }
    
    private var topPSlider: some View {
        sliderView(value: $assistantDetailViewModel.assistant.top_p, range: 0.0...1.0, label: "Top P")
    }
    
    private func sliderView(value: Binding<Double>, range: ClosedRange<Double>, label: String) -> some View {
        VStack {
            Text("\(label): \(value.wrappedValue, specifier: "%.2f")")
            Slider(value: value, in: range, step: 0.01)
        }
    }
    
    // MARK: - Save Handler
    private func handleSave() {
        if validateAssistant() {
            viewModel.updateAssistant(assistant: assistantDetailViewModel.assistant)
            presentationMode.wrappedValue.dismiss()
        } else {
            showAlert = true
        }
    }
    
    // MARK: - Validation
    private func validateAssistant() -> Bool {
        !assistantDetailViewModel.assistant.name.isEmpty && !assistantDetailViewModel.assistant.model.isEmpty
    }
}
