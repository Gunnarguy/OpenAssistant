import SwiftUI
import UIKit

struct InputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    var colorScheme: ColorScheme
    @FocusState var isTextFieldFocused: Bool  // Manages the text field's focus state

    // Define constants for font size, padding, and vertical alignment
    private let inputFontSize: CGFloat = 15
    private let horizontalPadding: CGFloat = 10
    // Single vertical padding - simpler approach to prevent text cut-off
    private let verticalPadding: CGFloat = 6
    private let minInputHeight: CGFloat = 40  // Minimum height for single line
    private let maxInputHeight: CGFloat = 120  // Maximum height before scrolling kicks in

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {  // Changed to bottom alignment for multiline support
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
        // Simplified ZStack with consistent padding for TextEditor and placeholder
        ZStack(alignment: .topLeading) {  // Changed to topLeading for multiline alignment
            // Placeholder text shown when input is empty
            if viewModel.inputText.isEmpty {
                Text("Type a message...")
                    .font(.system(size: inputFontSize))
                    .foregroundColor(Color(UIColor.placeholderText))
                    .padding(.top, 8)  // Align with text editor's top padding
            }

            // Multi-line text editor with dynamic height
            TextEditor(text: $viewModel.inputText)
                .focused($isTextFieldFocused)
                .font(.system(size: inputFontSize))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .background(Color.clear)
                .scrollContentBackground(.hidden)
                .scrollDisabled(false)  // Allow scrolling when content exceeds max height
                .onAppear {
                    DispatchQueue.main.async {
                        isTextFieldFocused = viewModel.shouldFocusTextField
                    }
                }
        }
        // Apply consistent horizontal and vertical padding
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(minHeight: minInputHeight, maxHeight: maxInputHeight)  // Dynamic height with constraints
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
