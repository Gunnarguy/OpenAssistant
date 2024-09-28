import Foundation
import Combine

@MainActor
class ContentViewModel: ObservableObject {
    @Published var selectedAssistant: Assistant?
    @Published var isLoading = false
    private var assistantManagerViewModel: AssistantManagerViewModel

    init(assistantManagerViewModel: AssistantManagerViewModel) {
        self.assistantManagerViewModel = assistantManagerViewModel
    }

    func startLoading() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
        }
    }

    func onAppear() {
        print("ContentView appeared")
    }

    func refreshContent() {
        // Logic to refresh and reload the entire app
        print("Refreshing content...")
        
        // Fetch the latest assistants
        assistantManagerViewModel.fetchAssistants()
        
        // Optionally, you can add more logic here to refresh other parts of the app
    }
}
