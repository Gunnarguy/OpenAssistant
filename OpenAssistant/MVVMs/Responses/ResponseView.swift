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
                        .autocapitalization(.none)
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
    static var previews: some View {
        let vm = ResponseViewModel(service: OpenAIService(apiKey: "test_key"))
        ResponseView(viewModel: vm)
    }
}
