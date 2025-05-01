import SwiftUI

struct ResponseView: View {
    @ObservedObject var viewModel: ResponseViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Model selection
                HStack {
                    Text("Model:")
                        .font(.subheadline)
                    TextField("Model", text: $viewModel.model)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)  // Correct placement
                }
                // Input text editor
                TextEditor(text: $viewModel.inputText)
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))

                // Send button
                Button(action: viewModel.sendRequest) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Send")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)

                // Display response
                ScrollView {
                    if let response = viewModel.response {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Response ID: \(response.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(response.output.indices, id: \.self) { idx in
                                let item = response.output[idx]
                                // Only handle message outputs
                                if item.type == "message", let contents = item.content {
                                    ForEach(contents.indices, id: \.self) { cidx in
                                        if let text = contents[cidx].text {
                                            Text(text)
                                                .padding(8)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(6)
                                        }
                                    }
                                } else {
                                    // Fallback for other output types
                                    Text("[\(item.type)]")
                                        .italic()
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .padding()
            .navigationTitle("Responses")
        }
    }
}

struct ResponseView_Previews: PreviewProvider {
    // Define mock structures outside the 'previews' property
    // to avoid issues with the ViewBuilder result builder.
    struct MockContent: Codable { let text: String? }
    struct MockOutput: Codable {
        let type: String
        let content: [MockContent]?
    }
    struct MockResponse: Codable {
        let id: String
        let output: [MockOutput]
    }

    static var previews: some View {
        // Wrap previews in a Group to satisfy ViewBuilder requirements
        Group {
            // Preview for the default empty state
            // Initialize VM directly within the View constructor
            ResponseView(viewModel: ResponseViewModel(service: OpenAIService(apiKey: "test_key")))
                .previewDisplayName("Empty State")

            // Preview for the loading state
            // Create and configure the VM before passing it to the View
            let loadingVM: ResponseViewModel = {
                let vm = ResponseViewModel(service: OpenAIService(apiKey: "test_key"))
                vm.isLoading = true  // Set loading state
                return vm
            }()  // Immediately execute the closure to get the configured VM
            ResponseView(viewModel: loadingVM)
                .previewDisplayName("Loading State")

            // Preview for the state with a response (using mock data)
            // Create and configure the VM before passing it to the View
            let simpleResponseVM: ResponseViewModel = {
                let vm = ResponseViewModel(service: OpenAIService(apiKey: "test_key"))
                vm.inputText = "User input text"  // Set some input text
                // TODO: Assign a mock ResponseModel object to vm.response here
                // This part still needs adjustment based on your actual ResponseModel.
                // Example (needs adaptation):
                /*
                let mockResponse = MockResponse(
                    id: "resp_12345",
                    output: [
                        MockOutput(type: "message", content: [MockContent(text: "This is a sample response message.")]),
                        MockOutput(type: "tool_call", content: nil)
                    ]
                )
                // Convert MockResponse to your actual ResponseModel if possible
                // vm.response = convertMockToActualResponseModel(mockResponse)
                */
                return vm
            }()  // Immediately execute the closure
            ResponseView(viewModel: simpleResponseVM)
                .previewDisplayName("With Response (Mock)")
        }
    }
}
