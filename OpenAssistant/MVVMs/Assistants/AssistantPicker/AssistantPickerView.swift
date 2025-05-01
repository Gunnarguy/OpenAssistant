import SwiftUI

/// Displays a list of available assistants and routes to a chat view when one is selected.
/// The view fetches data through `AssistantPickerViewModel` and reacts to loading / error / data states.
struct AssistantPickerView: View {
    // MARK: - Dependencies
    @StateObject private var viewModel = AssistantPickerViewModel()
    @ObservedObject var messageStore: MessageStore

    // MARK: - Body
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Select Assistant")
                .navigationBarTitleDisplayMode(.large)  // Use large titles for modern iOS look
        }
        // Load assistants the first time the view appears.
        .task { viewModel.fetchAssistants() }
        // Refresh when app-wide settings change (e.g. API key update).
        .onReceive(NotificationCenter.default.publisher(for: .settingsUpdated)) { _ in
            viewModel.fetchAssistants()
        }
    }

    // MARK: - Content Builder
    @ViewBuilder
    private var content: some View {
        // Use if/else if for state handling based directly on ViewModel properties
        if viewModel.isLoading {
            LoadingStateView()
        } else if let error = viewModel.errorMessage {
            // Pass the specific error message and retry action
            ErrorView(message: error.message, retryAction: viewModel.fetchAssistants)
        } else {
            assistantList
        }
    }

    // MARK: - Assistant List
    private var assistantList: some View {
        // Use List for standard iOS appearance and behavior
        List {
            // Iterate through assistants and display them in cards
            ForEach(viewModel.assistants) { assistant in
                // NavigationLink to transition to the ChatView
                NavigationLink {
                    ChatView(assistant: assistant, messageStore: messageStore)
                } label: {
                    // Wrap the card in a ZStack to potentially hide the default list chevron
                    ZStack {
                        AssistantCard(assistant: assistant)
                    }
                    // Ensure the entire ZStack area is tappable for the NavigationLink
                    .contentShape(Rectangle())
                }
                // Remove default padding for custom card layout
                .listRowInsets(EdgeInsets())
                // Apply padding around the card itself
                .padding(.horizontal)
                .padding(.vertical, 4)  // Reduced vertical padding between cards
            }
            // Set background to clear to allow List styling to show
            .listRowBackground(Color.clear)
            // Remove the default separator line
            .listRowSeparator(.hidden)
        }
        // Use insetGrouped style for modern card appearance within the list
        .listStyle(.insetGrouped)
        // Explicitly set background to ensure consistency
        .background(Color(uiColor: .systemGroupedBackground))
        // Hide scroll indicators for a cleaner look
        .scrollContentBackground(.hidden)  // Make List background transparent
    }
}

// MARK: - Row & Utility Sub-Views

/// A card view representing a single assistant in the list.
private struct AssistantCard: View {
    let assistant: Assistant

    // REMOVED: iconName(for:) function is no longer needed.

    var body: some View {
        HStack(spacing: 15) {  // Increased spacing for better visual separation
            // REMOVED: Assistant Icon Image view and its modifiers.

            // Assistant Name
            Text(assistant.name)
                .font(.headline)  // Use headline font for more emphasis
                .foregroundColor(.primary)

            Spacer()  // Pushes chevron to the right

                // Chevron indicating navigation
                .font(.system(size: 14, weight: .semibold))  // Slightly bolder chevron
                .foregroundColor(.secondary.opacity(0.7))  // Softer color
        }
        // Consistent padding within the card
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        // Use system background for adaptability
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        // Apply corner radius for card shape
        .cornerRadius(12)
        // Add a subtle shadow for depth
        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
        // Accessibility setup
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Select \(assistant.name)")
        .accessibilityHint("Navigates to chat screen")  // Add hint for better accessibility
    }
}

/// View displayed while assistants are being loaded.
private struct LoadingStateView: View {
    var body: some View {
        VStack {  // Wrap in VStack for centering
            ProgressView("Loading Assistants...")
                .controlSize(.large)  // Larger progress indicator
            Text("Please wait...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Center vertically and horizontally
        .background(Color(uiColor: .systemGroupedBackground))  // Match list background
        .accessibilityLabel("Loading Assistants")
    }
}

/// View displayed when loading assistants fails.
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        // Revert to VStack for broader compatibility and simpler structure
        VStack(spacing: 15) {
            // Error Icon
            Image(systemName: "exclamationmark.icloud.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)  // Keep icon size consistent
                .foregroundColor(.orange)  // Use a distinct error color

            // Error Title
            Text("Failed to Load Assistants")
                .font(.headline)

            // Error Message Description
            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Retry Button
            Button {
                retryAction()
            } label: {
                Text("Retry")
                    .padding(.horizontal)
            }
            .buttonStyle(.borderedProminent)  // Use prominent style for primary action
            .controlSize(.regular)
            .padding(.top, 5)  // Add slight spacing above the button
        }
        .padding()  // Add padding around the VStack content
        // Ensure the VStack fills the available space
        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
        .background(Color(uiColor: .systemGroupedBackground))  // Match list background
        .accessibilityElement(children: .combine)  // Combine elements for accessibility
        .accessibilityLabel("Error: \(message). Retry button.")
    }
}

// MARK: - Previews
struct AssistantPickerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview in light mode
            AssistantPickerView(messageStore: MessageStore())
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")

            // Preview in dark mode
            AssistantPickerView(messageStore: MessageStore())
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}

// Additional previews for loading and error states
struct AssistantPickerView_States_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Loading state preview
            LoadingStateView()
                .previewDisplayName("Loading State")

            // Error state preview
            ErrorView(message: "Sample error occurred", retryAction: {})
                .previewDisplayName("Error State")
        }
    }
}
