import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    @StateObject private var messageStore = MessageStore()  // Object handling messages

    init(assistantManagerViewModel: AssistantManagerViewModel) {
        _viewModel = StateObject(wrappedValue: ContentViewModel(assistantManagerViewModel: assistantManagerViewModel))
    }

    var body: some View {
        ZStack {
            MainTabView(selectedAssistant: $viewModel.selectedAssistant, messageStore: messageStore)
            if viewModel.isLoading {
                LoadingView()
                    .onAppear(perform: viewModel.startLoading)
            }
        }
        .onAppear(perform: viewModel.onAppear) // Called when view appears
        .onReceive(NotificationCenter.default.publisher(for: .settingsUpdated)) { _ in
            viewModel.refreshContent()
        }
        .environmentObject(viewModel) // Provide the viewModel to the environment
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(assistantManagerViewModel: AssistantManagerViewModel())
    }
}
