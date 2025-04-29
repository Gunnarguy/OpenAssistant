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
        if viewModel.isLoading {
            LoadingStateView()
        } else if let error = viewModel.errorMessage {
            ErrorView(message: error.message, retryAction: viewModel.fetchAssistants)
        } else {
            assistantList
        }
    }

    // MARK: - Assistant List
    private var assistantList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.assistants) { assistant in
                    NavigationLink {
                        ChatView(assistant: assistant, messageStore: messageStore)
                    } label: {
                        AssistantCard(assistant: assistant)
                    }
                    .buttonStyle(.plain) // Remove default list row highlight for a cleaner card effect
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - Row & Utility Sub-Views
private struct AssistantCard: View {
    let assistant: Assistant

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: assistant.iconName ?? "brain.head.profile")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .padding(8)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())

            Text(assistant.name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Select \(assistant.name)")
    }
}

private struct LoadingStateView: View {
    var body: some View {
        ProgressView("Loading Assistants...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Loading Assistants")
    }
}

// MARK: - Error View (unchanged)
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.icloud.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.orange)
            Text("Failed to Load Assistants")
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message). Retry button.")
    }
}

// MARK: - Preview
struct AssistantPickerView_Previews: PreviewProvider {
    static var previews: some View {
        AssistantPickerView(messageStore: MessageStore())
    }
}
