import SwiftUI

struct AssistantPickerView: View {
    @StateObject private var viewModel = AssistantPickerViewModel()
    @ObservedObject var messageStore: MessageStore

    var body: some View {
        // Use NavigationView for push navigation
        NavigationView {
            content
                .navigationTitle("Select Assistant")
            // Removed .sheet modifier
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
        // Center the ProgressView
        if viewModel.isLoading {
            VStack {  // Wrap in VStack to allow centering
                Spacer()
                ProgressView("Loading Assistants...")
                Spacer()
            }
        } else if let error = viewModel.errorMessage {
            ErrorView(message: error.message, retryAction: viewModel.fetchAssistants)
        } else {
            assistantList
        }
    }

    private var assistantList: some View {
        List {  // Removed explicit type List(viewModel.assistants) for cleaner NavigationLink usage
            ForEach(viewModel.assistants) { assistant in
                // Use NavigationLink for direct navigation
                NavigationLink(
                    destination: ChatView(assistant: assistant, messageStore: messageStore)
                ) {
                    // Use Label for semantic content (icon + text)
                    Label {
                        Text(assistant.name)
                            .font(.headline)  // Keep headline font
                    } icon: {
                        // Add a relevant icon
                        Image(systemName: "brain.head.profile")  // Example icon
                            .foregroundColor(.accentColor)  // Use accent color for the icon
                    }
                    .padding(.vertical, 8)  // Adjust vertical padding for better spacing
                }
                .accessibilityLabel("Select \(assistant.name)")  // Keep accessibility
            }
        }
        .listStyle(InsetGroupedListStyle())  // Keep the list style
    }
}

// ErrorView remains largely the same, could be further styled if desired
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 15) {  // Add spacing
            Image(systemName: "exclamationmark.icloud.fill")  // Example of a potentially more modern icon
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.orange)  // Softer color than red
            Text("Failed to Load Assistants")  // More user-friendly title
                .font(.headline)
            Text(message)  // Keep the specific error message
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry", action: retryAction)
                .buttonStyle(.borderedProminent)  // More prominent button style
        }
        .padding()  // Add padding around the VStack
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Center the error view
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message). Retry button.")
    }
}

struct AssistantPickerView_Previews: PreviewProvider {
    static var previews: some View {
        AssistantPickerView(messageStore: MessageStore())
    }
}
