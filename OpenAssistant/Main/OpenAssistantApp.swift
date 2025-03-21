import Foundation
import Combine
import SwiftUI

@main
struct OpenAssistantApp: App {
    // MARK: - Properties
    @StateObject private var assistantManagerViewModel = AssistantManagerViewModel()
    @StateObject private var vectorStoreViewModel = VectorStoreManagerViewModel()
    @State private var selectedAssistant: Assistant?
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""
    @State private var showSettingsView = false

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView(assistantManagerViewModel: assistantManagerViewModel)
                .environmentObject(assistantManagerViewModel)
                .environmentObject(vectorStoreViewModel)
                .onAppear(perform: handleOnAppear)
                .sheet(isPresented: $showSettingsView) {
                    SettingsView()
                        .environmentObject(assistantManagerViewModel)
                }
        }
    }

    // MARK: - Methods
    /// Handles actions to perform when the view appears
    private func handleOnAppear() {
        assistantManagerViewModel.fetchAssistants()
        showSettingsView = apiKey.isEmpty
    }
}
