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
        // Setup bindings with the assistant manager view model if needed
        // Example:
        // assistantManagerViewModel.$somePublishedProperty
        //     .receive(on: DispatchQueue.main)
        //     .sink { [weak self] value in
        //         self?.handleValueChange(value)
        //     }
        //     .store(in: &cancellables)
    }

    func startLoading() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isLoading = false
        }
    }

    func onAppear() {
        print("ContentView appeared")
    }

    func refreshContent() {
        print("Refreshing content...")
        assistantManagerViewModel.fetchAssistants()
        // Add more logic here to refresh other parts of the app if necessary
    }
}
