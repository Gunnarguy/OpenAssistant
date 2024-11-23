import SwiftUI
import Combine

struct AssistantDetailsSection: View {
    @Binding var assistant: Assistant
    var availableModels: [String]
    @Binding var showVectorStoreDetail: Bool
    @ObservedObject var vectorStoreManagerViewModel: VectorStoreManagerViewModel

    @State private var vectorStore: VectorStore? // Changed to @State
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack {
            Section(header: Text("Assistant Details")) {
                NameField(name: $assistant.name)
                InstructionsField(instructions: Binding($assistant.instructions, default: ""))
                ModelPicker(model: $assistant.model, availableModels: availableModels)
                DescriptionField(description: Binding($assistant.description, default: ""))
                TemperatureSlider(temperature: $assistant.temperature)
                TopPSlider(topP: $assistant.top_p)
            }

            Group {
                if let vectorStore = vectorStore {
                    Section(header: Text("Vector Store")) {
                        Text("Name: \(vectorStore.name ?? "Unnamed")")
                        Text("ID: \(vectorStore.id)")
                        Text("Created At: \(formattedDate(from: vectorStore.createdAt))")
                        Button("View Details") {
                            showVectorStoreDetail = true
                        }
                    }
                } else {
                    Section(header: Text("Vector Store")) {
                        VStack {
                            Text("No associated vector store found.")
                                .foregroundColor(.gray)
                            Button("Create and Attach Vector Store") {
                                createAndAttachVectorStore()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func createAndAttachVectorStore() {
        let vectorStoreName = "Vector store for \(assistant.name)"

        vectorStoreManagerViewModel
            .createVectorStore(name: vectorStoreName)
            .flatMap { vectorStoreId -> AnyPublisher<VectorStore, Error> in
                // Fetch the newly created VectorStore
                return self.vectorStoreManagerViewModel.fetchVectorStore(id: vectorStoreId)
            }
            .flatMap { fetchedVectorStore -> AnyPublisher<Void, Error> in
                self.vectorStore = fetchedVectorStore // Assign the value
                return Future<Void, Error> { promise in
                    Task {
                        do {
                            try await self.vectorStoreManagerViewModel.attachVectorStoreToAssistant(
                                assistantId: self.assistant.id,
                                vectorStoreId: fetchedVectorStore.id
                            )
                            promise(.success(()))
                        } catch {
                            promise(.failure(error))
                        }
                    }
                }.eraseToAnyPublisher()
            }
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

private extension Binding where Value == String {
    init(_ source: Binding<String?>, default defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0 }
        )
    }
}