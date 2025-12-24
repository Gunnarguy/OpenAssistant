import Combine
import Foundation
import SwiftUI
import Firebase

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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
                .onOpenURL(perform: handleDeepLink)  // Handle deep links
                .sheet(isPresented: $showSettingsView) {
                    SettingsView(
                        assistantManagerViewModel: assistantManagerViewModel,
                        vectorStoreViewModel: vectorStoreViewModel
                    )
                }
        }
    }

    // MARK: - Methods
    private func handleOnAppear() {
        assistantManagerViewModel.fetchAssistants()
        showSettingsView = apiKey.isEmpty
    }
}

