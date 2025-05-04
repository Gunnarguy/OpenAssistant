import SwiftUI

struct InputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    var colorScheme: ColorScheme
    @FocusState var isTextFieldFocused: Bool  // Manages the text field's focus state

    // Define constants for font size and padding for easier adjustment
    private let inputFontSize: CGFloat = 15
    // private let verticalPadding: CGFloat = 8 // No longer directly used for TextEditor padding
    private let horizontalPadding: CGFloat = 10
    private let inputAreaHeight: CGFloat = 36  // Fixed height matching SendButton

    var body: some View {
        HStack(alignment: .center, spacing: 8) {  // Align items vertically center
            // Message Input Text Field Area
            inputFieldArea

            // Send Button
            SendButton(
                action: {
                    Task { @MainActor in viewModel.sendMessage() }
                },
                isDisabled: viewModel.inputText.isEmpty || viewModel.isLoading,
                isLoading: viewModel.isLoading
            )
            // SendButton height is approx. 16 (icon) + 2*10 (padding) = 36
        }
        // Padding is now applied in ChatContentView
        // Sync focus state from ViewModel
        .onChange(of: viewModel.shouldFocusTextField) { shouldFocus in
            isTextFieldFocused = shouldFocus
        }
        // Request focus when view appears if needed (optional)
        // .onAppear {
        //     DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //         isTextFieldFocused = true
        //     }
        // }
    }

    // MARK: - Subviews

    // Removed: historyButton View Builder
    // Removed: historyButtonContent helper function

    // Extracted Text Field Area View Builder
    @ViewBuilder
    private var inputFieldArea: some View {
        // Use a custom TextEditor for multi-line input, wrapped in a shape
        HStack(alignment: .center, spacing: 0) {  // Center align content vertically
            ZStack(alignment: .leading) {
                // Placeholder text shown when input is empty
                if viewModel.inputText.isEmpty {
                    Text("Type a message...")
                        .font(.system(size: inputFontSize))  // Use constant
                        .foregroundColor(Color(UIColor.placeholderText))
                        .padding(.horizontal, horizontalPadding + 2)  // Keep horizontal padding
                        // Vertical padding calculated to center in fixed height
                        .padding(.vertical, (inputAreaHeight - inputFontSize) / 2)
                }

                // Use TextEditor for multi-line support
                TextEditor(text: $viewModel.inputText)
                    .focused($isTextFieldFocused)  // Bind focus state
                    .font(.system(size: inputFontSize))  // Use constant
                    // Remove min/max height, let it fill the container
                    // .frame(minHeight: 24, maxHeight: 70)
                    .padding(.horizontal, horizontalPadding - 3)  // Inner horizontal padding for text
                    // Vertical padding calculated to center in fixed height
                    .padding(.vertical, (inputAreaHeight - inputFontSize) / 2)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .background(Color.clear)  // Make TextEditor background transparent
                    .scrollContentBackground(.hidden)  // Hide default scroll view background (iOS 16+)
                    .onAppear {  // Workaround to ensure focus works reliably
                        DispatchQueue.main.async {
                            isTextFieldFocused = viewModel.shouldFocusTextField
                        }
                    }
                    // Allow vertical scrolling if text exceeds the height
                    .scrollDisabled(false)

            }
        }
        .padding(.horizontal, 3)  // Reduced padding around ZStack
        // Remove outer vertical padding
        // .padding(.vertical, 3)
        .frame(height: inputAreaHeight)  // Apply fixed height to the container
        .background(Color(UIColor.systemGray6))  // Use slightly lighter gray
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))  // Slightly smaller radius
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)  // Match radius
                .stroke(
                    isTextFieldFocused ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.2),
                    lineWidth: 1)  // Adjusted border
        )
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)  // Even softer shadow
        .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)  // Animate border change
        // Submit action (e.g., when hardware keyboard return is pressed)
        // Note: TextEditor doesn't have a direct onCommit like TextField.
        // Sending is primarily handled by the SendButton.
    }
}
