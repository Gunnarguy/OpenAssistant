import Combine
import Foundation
import SwiftUI
import Firebase
import UIKit
import FirebaseCore

class AppLifecycleDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

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
    @UIApplicationDelegateAdaptor(AppLifecycleDelegate.self) var appDelegate

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
                    SettingsView()
                        .environmentObject(assistantManagerViewModel)
                }
        }
    }

    // MARK: - Methods
    private func handleOnAppear() {
        assistantManagerViewModel.fetchAssistants()
        showSettingsView = apiKey.isEmpty
    }
    
    private func handleDeepLink(_ url: URL) {
        #if DEBUG
        print("Received deep link: \(url.absoluteString)")
        #endif
        // Example: open settings when the URL indicates it
        if url.host == "settings" || url.pathComponents.contains("settings") {
            showSettingsView = true
        }
    }
}

