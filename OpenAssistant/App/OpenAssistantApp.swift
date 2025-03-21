import SwiftUI

@main
struct OpenAssistantApp: App {
    // Create shared view models at the app level
    @StateObject private var vectorStoreViewModel = VectorStoreManagerViewModel(
        openAIService: ServiceProvider.shared.openAIService
    )
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject view models into the environment
                .environmentObject(vectorStoreViewModel)
        }
    }
}
