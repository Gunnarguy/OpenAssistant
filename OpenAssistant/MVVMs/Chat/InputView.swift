import SwiftUI

struct InputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    var colorScheme: ColorScheme
    @FocusState var isTextFieldFocused: Bool  // Manages the text field's focus state

    var body: some View {
        HStack {
            // History Button (conditionally enabled)
            historyButton

            // Message Input Text Field
            messageTextField

            // Send Button (refactored)
            SendButton(
                action: {
                    // Ensure send message is dispatched asynchronously on the main actor
                    Task { @MainActor in
                        viewModel.sendMessage()
                    }
                },
                isDisabled: viewModel.inputText.isEmpty || viewModel.isLoading,
                isLoading: viewModel.isLoading
            )
            .padding(.leading, 5)  // Add spacing
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
        // Sync focus state from ViewModel
        .onChange(of: viewModel.shouldFocusTextField) { shouldFocus in
            isTextFieldFocused = shouldFocus
        }
    }

    // MARK: - Subviews

    // Extracted History Button View Builder
    @ViewBuilder
    private var historyButton: some View {
        if let threadId = viewModel.threadId {
            NavigationLink(
                destination: ChatHistoryView(
                    messageStore: messageStore,
                    threadId: threadId
                )
            ) {
                historyButtonContent(enabled: true)
            }
        } else {
            historyButtonContent(enabled: false)
        }
    }

    // Reusable content for the history button
    private func historyButtonContent(enabled: Bool) -> some View {
        Image(systemName: "clock")
            .foregroundColor(enabled ? .blue : .gray)
            .padding(14)
            .background(Color(UIColor.systemGray5))
            .cornerRadius(25)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
    }

    // Extracted Text Field View Builder
    @ViewBuilder
    private var messageTextField: some View {
        TextField(
            "Type a message",
            text: $viewModel.inputText,
            onCommit: {
                // Send message on commit (e.g., pressing return)
                // Ensure send message is dispatched asynchronously on the main actor
                Task { @MainActor in
                    viewModel.sendMessage()
                }
            }
        )
        .focused($isTextFieldFocused)  // Bind focus state
        .padding(16)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(25)
        .foregroundColor(colorScheme == .dark ? .white : .black)
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.blue, lineWidth: 1)
        )
        // Removed the .onChange(of: isTextFieldFocused) here,
        // as we handle the focus change sync back to the VM elsewhere if needed.
    }
}
