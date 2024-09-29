import Foundation
import Combine
import SwiftUI

@main
struct OpenAssistantApp: App {
    @StateObject private var assistantManagerViewModel = AssistantManagerViewModel()
    @State private var selectedAssistant: Assistant?

    var body: some Scene {
        WindowGroup {
            ContentView(assistantManagerViewModel: assistantManagerViewModel)
                .environmentObject(assistantManagerViewModel)
                .onAppear(perform: setup)
        }
    }

    private func setup() {
        assistantManagerViewModel.fetchAssistants()
    }
}
