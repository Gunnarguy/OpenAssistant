import SwiftUI

struct InputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    var colorScheme: ColorScheme
    @FocusState var isTextFieldFocused: Bool  // Add FocusState

    var body: some View {
        HStack {
            // Only show the history button if we have a valid thread ID
            if let threadId = viewModel.threadId {
                NavigationLink(
                    destination: ChatHistoryView(
                        messages: messageStore.messages, threadId: threadId)
                ) {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                        .padding(14)
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                }
            } else {
                // Disabled state when no thread exists
                Image(systemName: "clock")
                    .foregroundColor(.gray)
                    .padding(14)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(25)
            }

            TextField(
                "Type a message", text: $viewModel.inputText,
                onCommit: {
                    // Keep onCommit if you want send on return key, otherwise remove
                    viewModel.sendMessage()
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
            SendButton(viewModel: viewModel, messageStore: messageStore)
                // Ensure button tap dismisses keyboard
                .onTapGesture {
                    viewModel.sendMessage()  // Send message will now handle focus
                }
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
        // Sync view model's focus request with the FocusState
        // Use newer onChange with initial parameter on iOS 17+
        if #available(iOS 17.0, *) {
            let _ = Self._printChanges() // Added to satisfy the compiler about the result of onChange
            // The actual onChange modifier
            self.onChange(of: viewModel.shouldFocusTextField) { _, shouldFocus in
                 isTextFieldFocused = shouldFocus
             }
             // Update view model when focus changes externally (e.g., user taps out)
             .onChange(of: isTextFieldFocused) { _, focused in
                  if !focused {
                      viewModel.textFieldDidLoseFocus()
                  }
             }
        } else {
            // Fallback for iOS 16 - use the older onChange without 'initial'
             self.onChange(of: viewModel.shouldFocusTextField) { shouldFocus in
                 isTextFieldFocused = shouldFocus
             }
             .onChange(of: isTextFieldFocused) { focused in
                  if !focused {
                      viewModel.textFieldDidLoseFocus()
                  }
             }
        }
    }
}
