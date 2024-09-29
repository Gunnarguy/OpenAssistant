import Foundation
import Combine
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    @Published var selectedAssistant: Assistant?
    @Published var isLoading = false
    private let assistantManagerViewModel: AssistantManagerViewModel
    private var cancellables = Set<AnyCancellable>()

    init(assistantManagerViewModel: AssistantManagerViewModel) {
        self.assistantManagerViewModel = assistantManagerViewModel
        setupBindings()
    }

    private func setupBindings() {
        // Example of setting up bindings if needed
        // assistantManagerViewModel.$somePublishedProperty
        //     .sink { [weak self] value in
        //         self?.handleValueChange(value)
        //     }
        //     .store(in: &cancellables)
    }

    func startLoading() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
        }
    }

    func onAppear() {
        print("ContentView appeared")
    }

    func refreshContent() {
        print("Refreshing content...")
        assistantManagerViewModel.fetchAssistants()
        // Optionally, add more logic here to refresh other parts of the app
    }
}
