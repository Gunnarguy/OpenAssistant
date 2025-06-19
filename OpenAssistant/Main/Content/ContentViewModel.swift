import Combine
import Foundation
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedAssistant: Assistant?
    @Published var loadingMessage: String?

    // MARK: - Computed Properties
    var isLoading: Bool {
        loadingMessage != nil
    }

    // MARK: - Private Properties
    private let assistantManagerViewModel: AssistantManagerViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(assistantManagerViewModel: AssistantManagerViewModel) {
        self.assistantManagerViewModel = assistantManagerViewModel
        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        // Will be implemented as needed
    }

    // MARK: - Public Methods
    /// Called when the ContentView appears
    func onAppear() {
        logEvent("ContentView appeared")
        refreshContent()
    }

    /// Refreshes content after settings changes
    func refreshContent() {
        logEvent("Refreshing content")
        loadingMessage = "Updating assistants..."
        Task {
            // Simulate network delay for better visual feedback
            try? await Task.sleep(for: .seconds(1.5))
            assistantManagerViewModel.fetchAssistants()

            await MainActor.run {
                loadingMessage = nil
            }
        }
    }

    // MARK: - Private Methods
    private func logEvent(_ message: String) {
        #if DEBUG
            print("ContentViewModel: \(message)")
        #endif
    }
}
