import Combine
import Foundation
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    @EnvironmentObject private var messageStore: MessageStore  // Access from environment
    @EnvironmentObject private var vectorStoreViewModel: VectorStoreManagerViewModel  // Assuming this is also in environment

    // Removed local vectorStoreViewModel initialization
    // Removed local messageStore initialization

    init(assistantManagerViewModel: AssistantManagerViewModel) {
        _viewModel = StateObject(
            wrappedValue: ContentViewModel(assistantManagerViewModel: assistantManagerViewModel))
    }

    var body: some View {
        ZStack {
            // Pass the environment messageStore explicitly to MainTabView's initializer
            MainTabView(
                selectedAssistant: $viewModel.selectedAssistant,
                vectorStoreViewModel: vectorStoreViewModel,  // Pass from environment
                messageStore: messageStore  // Pass the environment object here
            )
            if viewModel.isLoading {
                LoadingView()
                    .onAppear(perform: viewModel.startLoading)
            }
        }
        .onAppear(perform: viewModel.onAppear)
        .onReceive(NotificationCenter.default.publisher(for: .settingsUpdated)) { _ in
            viewModel.refreshContent()
        }
        .environmentObject(viewModel)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview needs the environment objects
        ContentView(assistantManagerViewModel: AssistantManagerViewModel())
            .environmentObject(MessageStore())  // Provide dummy store for preview
            .environmentObject(VectorStoreManagerViewModel())  // Provide dummy store for preview
            .environmentObject(AssistantManagerViewModel())  // Provide dummy manager for preview
    }
}
