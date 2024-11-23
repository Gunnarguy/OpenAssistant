import SwiftUI
import Foundation
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
            if let vectorStore = vectorStoreManagerViewModel.vectorStore {
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
                if vectorStoreManagerViewModel.assistant != nil {
                    Button("Create and Attach Vector Store") {
                        Task {
                            do {
                                try await createAndAttachVectorStore()
                                alertMessage = "Vector store successfully created and attached."
                            } catch {
                                alertMessage = "Error: \(error.localizedDescription)"
                            }
                            showAlert = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Cannot create a vector store without an assistant.")
                        .foregroundColor(.red)
                }
            }
        }
    }
    private func addFileToVectorStore(vectorStoreId: String, fileId: String) async throws {
        guard let request = createRequest(endpoint: "vector_stores/\(vectorStoreId)/files", method: "POST", body: [
            "file_ids": [fileId]
        ]) else {
            throw URLError(.badURL)
        }

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func createRequest(endpoint: String, method: String, body: [String: Any]) -> URLRequest? {
        guard let url = URL(string: "https://api.openai.com/v1/\(endpoint)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer YOUR_API_KEY", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            return nil
        }

        return request
    }
    func createAndAttachVectorStore() async throws {
        try await vectorStoreManagerViewModel.createAndAttachVectorStore()
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
