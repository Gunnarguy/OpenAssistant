import Combine
import Foundation
import SwiftUI

@main
struct OpenAssistantApp: App {
    // MARK: - Properties
    @StateObject private var assistantManagerViewModel = AssistantManagerViewModel()
    @StateObject private var vectorStoreViewModel = VectorStoreManagerViewModel()
    @StateObject private var messageStore = MessageStore()  // Create the single instance here
    @State private var selectedAssistant: Assistant?
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""
    @State private var showSettingsView = false

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView(assistantManagerViewModel: assistantManagerViewModel)
                .environmentObject(assistantManagerViewModel)
                .environmentObject(vectorStoreViewModel)
                .environmentObject(messageStore)  // Inject into the environment
                .onAppear(perform: handleOnAppear)
                .sheet(isPresented: $showSettingsView) {
                    SettingsView()
                        .environmentObject(assistantManagerViewModel)
                    // Inject messageStore into SettingsView if needed
                    // .environmentObject(messageStore)
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
