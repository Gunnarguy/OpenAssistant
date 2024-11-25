import Foundation
import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    @StateObject private var messageStore = MessageStore()  // Object handling messages
    @StateObject private var vectorStoreManagerViewModel = VectorStoreManagerViewModel()  // Add this line

    init(assistantManagerViewModel: AssistantManagerViewModel) {
        _viewModel = StateObject(wrappedValue: ContentViewModel(assistantManagerViewModel: assistantManagerViewModel))
    }

    var body: some View {
        ZStack {
            MainTabView(selectedAssistant: $viewModel.selectedAssistant, viewModel: vectorStoreManagerViewModel, messageStore: messageStore)  // Update this line
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
        ContentView(assistantManagerViewModel: AssistantManagerViewModel())
    }
}
