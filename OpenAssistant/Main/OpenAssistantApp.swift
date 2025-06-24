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
    // Read the stored appearance mode preference
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode.RawValue =
        AppearanceMode.system.rawValue
    @State private var showSettingsView = false

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView(assistantManagerViewModel: assistantManagerViewModel)
                .environmentObject(assistantManagerViewModel)
                .environmentObject(vectorStoreViewModel)
                .environmentObject(messageStore)  // Inject into the environment
                // Apply the preferred color scheme globally based on settings
                .preferredColorScheme(
                    (AppearanceMode(rawValue: appearanceMode) ?? .system).colorScheme
                )
                .onAppear(perform: handleOnAppear)
                .sheet(isPresented: $showSettingsView) {
                    // Wrap SettingsView in NavigationView to show title and Done button
                    NavigationView {
                        SettingsView()
                            .environmentObject(assistantManagerViewModel)
                        // Inject messageStore into SettingsView if needed
                        // .environmentObject(messageStore)
                    }
                    // Apply preferred color scheme to the sheet as well
                    .preferredColorScheme(
                        (AppearanceMode(rawValue: appearanceMode) ?? .system).colorScheme)
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
