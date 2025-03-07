import SwiftUI

struct AssistantPickerView: View {
    @StateObject private var viewModel = AssistantPickerViewModel()
    @ObservedObject var messageStore: MessageStore

    var body: some View {
        NavigationView {
            content
                .navigationTitle("Select Assistant")
                .sheet(item: $viewModel.selectedAssistant) { assistant in
                    ChatView(assistant: assistant, messageStore: messageStore)
                }
        }
        .onAppear {
            viewModel.fetchAssistants()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsUpdated)) { _ in
            viewModel.fetchAssistants()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Loading...")
        } else if let error = viewModel.errorMessage {
            ErrorView(message: error.message, retryAction: viewModel.fetchAssistants)
        } else {
            assistantList
        }
    }

    private var assistantList: some View {
        List(viewModel.assistants) { assistant in
            Button(action: { viewModel.selectAssistant(assistant) }) {
                HStack {
                    Text(assistant.name)
                        .font(.headline)
                        .padding(.vertical, 6)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Select \(assistant.name)")
        }
        .listStyle(InsetGroupedListStyle())
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.red)
                .padding(.bottom, 10)
            Text(message)
                .font(.body)
                .foregroundColor(.red)
                .padding()
            Button("Retry", action: retryAction)
                .padding(.top, 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message). Retry button.")
    }
}

struct AssistantPickerView_Previews: PreviewProvider {
    static var previews: some View {
        AssistantPickerView(messageStore: MessageStore())
    }
}
