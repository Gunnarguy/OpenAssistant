import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel() // ViewModel handling app state
    @StateObject private var messageStore = MessageStore()  // Object handling messages

    var body: some View {
        ZStack {
            MainTabView(selectedAssistant: $viewModel.selectedAssistant, messageStore: messageStore)
            if viewModel.isLoading {
                LoadingView()
                    .onAppear(perform: viewModel.startLoading)
            }
        }
        .onAppear(perform: viewModel.onAppear) // Called when view appears
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
