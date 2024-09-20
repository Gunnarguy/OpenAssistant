import SwiftUI

@main
struct OpenAssistantApp: App {
    @StateObject private var assistantManagerViewModel = AssistantManagerViewModel()
    @State private var selectedAssistant: Assistant?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(assistantManagerViewModel)
                .onAppear(perform: setup)
        }
    }

    // MARK: - Setup

    private func setup() {
        // Perform any necessary setup here
        assistantManagerViewModel.fetchAssistants()
    }
}