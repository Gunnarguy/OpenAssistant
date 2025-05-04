import Foundation
import Combine
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    // MARK: - Loading State Enum
    enum LoadingState {
        case idle
        case loading
        case completed
    }
    
    // MARK: - Published Properties
    @Published var selectedAssistant: Assistant?
    @Published private(set) var loadingState: LoadingState = .idle
    
    // MARK: - Computed Properties
    var isLoading: Bool {
        loadingState == .loading
    }
    
    // MARK: - Private Properties
    private let assistantManagerViewModel: AssistantManagerViewModel
    private var cancellables = Set<AnyCancellable>()
    private let loadingTime: TimeInterval = 2.0

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
    /// Simulates loading for UI transitions
    func startLoading() {
        guard loadingState != .loading else { return }
        
        loadingState = .loading
        DispatchQueue.main.asyncAfter(deadline: .now() + loadingTime) { [weak self] in
            Task { @MainActor in
                self?.loadingState = .completed
            }
        }
    }

    /// Called when the ContentView appears
    func onAppear() {
        logEvent("ContentView appeared")
    }

    /// Refreshes content after settings changes
    func refreshContent() {
        logEvent("Refreshing content")
        assistantManagerViewModel.fetchAssistants()
    }
    
    // MARK: - Private Methods
    private func logEvent(_ message: String) {
        #if DEBUG
        print("ContentViewModel: \(message)")
        #endif
    }
}
