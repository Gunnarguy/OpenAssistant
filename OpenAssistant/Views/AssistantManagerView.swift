import SwiftUI

struct AssistantManagerView: View {
    // Access the shared view model from the environment
    @EnvironmentObject var vectorStoreViewModel: VectorStoreManagerViewModel
    
    // Local state just for this view
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            // Your tab selection UI
            
            // Content for the selected tab
            TabView(selection: $selectedTab) {
                // Your tabs here
            }
        }
        .onAppear {
            print("Assistant Manager View appeared")
            // Fetch data only once when the view appears
            vectorStoreViewModel.fetchVectorStores()
        }
    }
}
