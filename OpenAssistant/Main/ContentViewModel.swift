import Foundation
import Combine

@MainActor
class ContentViewModel: ObservableObject {
    @Published var selectedAssistant: Assistant?
    @Published var isLoading = false

    func startLoading() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
        }
    }

    func onAppear() {
        print("ContentView appeared")
    }
}
