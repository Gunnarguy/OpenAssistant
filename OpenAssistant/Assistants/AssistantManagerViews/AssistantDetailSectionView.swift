import SwiftUI
import Combine

struct AssistantDetailsSection: View {
    @Binding var assistant: Assistant
    var availableModels: [String]
    @Binding var showVectorStoreDetail: Bool
    @ObservedObject var vectorStoreManagerViewModel: VectorStoreManagerViewModel
    var vectorStore: VectorStore?
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack {
            assistantDetailsSection
            vectorStoreSection
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var assistantDetailsSection: some View {
        Section(header: Text("Assistant Details")) {
            NameField(name: $assistant.name)
            InstructionsField(instructions: Binding(
                get: { assistant.instructions ?? "" },
                set: { assistant.instructions = $0.isEmpty ? nil : $0 }
            ))
            ModelPicker(model: $assistant.model, availableModels: availableModels)
            if let description = assistant.description {
                DescriptionField(description: Binding(
                    get: { description },
                    set: { assistant.description = $0.isEmpty ? nil : $0 }
                ))
            }
            TemperatureSlider(temperature: $assistant.temperature)
            TopPSlider(topP: $assistant.top_p)
        }
    }

    private var vectorStoreSection: some View {
        Group {
            if let vectorStore = vectorStore {
                vectorStoreDetailsSection(vectorStore: vectorStore)
            } else {
                noVectorStoreSection
            }
        }
    }

    private func vectorStoreDetailsSection(vectorStore: VectorStore) -> some View {
        Section(header: Text("Vector Store")) {
            Text("Name: \(vectorStore.name ?? "Unnamed")")
            Text("ID: \(vectorStore.id)")
            Text("Created At: \(formattedDate(from: vectorStore.createdAt))")
            Button("View Details") {
                showVectorStoreDetail = true
            }
        }
    }

    private var noVectorStoreSection: some View {
        Section(header: Text("Vector Store")) {
            VStack {
                Text("No associated vector store found.")
                    .foregroundColor(.gray)
                Button("Create and Attach Vector Store") {
                    createAndAttachVectorStore()
                        .sink(receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                alertMessage = "Failed to create and attach vector store: \(error.localizedDescription)"
                                showAlert = true
                            }
                        }, receiveValue: { _ in
                            // Handle success if needed
                        })
                        .store(in: &cancellables)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    func createAndAttachVectorStore() -> AnyPublisher<Void, Error> {
        vectorStoreManagerViewModel.createAndAttachVectorStore()
    }

    private func formattedDate(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

private struct ModelPicker: View {
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

private struct DescriptionField: View {
    @Binding var description: String
    var body: some View {
        TextField("Description", text: $description)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

private struct TemperatureSlider: View {
    @Binding var temperature: Double
    var body: some View {
        VStack {
            Text("Temperature: \(temperature, specifier: "%.2f")")
            Slider(value: $temperature, in: 0...1)
        }
    }
}

private struct TopPSlider: View {
    @Binding var topP: Double
    var body: some View {
        VStack {
            Text("Top P: \(topP, specifier: "%.2f")")
            Slider(value: $topP, in: 0...1)
        }
    }
}
