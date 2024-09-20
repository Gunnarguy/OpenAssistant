import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var messageStore = MessageStore()

    var body: some View {
        ZStack {
            MainTabView(selectedAssistant: $viewModel.selectedAssistant, messageStore: messageStore)
            if viewModel.isLoading {
                LoadingView()
                    .onAppear(perform: viewModel.startLoading)
            }
        }
        .onAppear(perform: viewModel.onAppear)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
