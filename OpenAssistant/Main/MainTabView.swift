import Combine
import Foundation
import SwiftUI

// MARK: - MainTabView
struct MainTabView: View {
    // MARK: - Properties
    @Binding var selectedAssistant: Assistant?
    @ObservedObject var vectorStoreViewModel: VectorStoreManagerViewModel
    @ObservedObject var messageStore: MessageStore
    @State private var selectedTab: Tab = .assistants

    // Store API key and response VM
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""

    // Custom init to set up ResponseViewModel
    init(
        selectedAssistant: Binding<Assistant?>,
        vectorStoreViewModel: VectorStoreManagerViewModel,
        messageStore: MessageStore
    ) {
        self._selectedAssistant = selectedAssistant
        self.vectorStoreViewModel = vectorStoreViewModel
        self.messageStore = messageStore
    }

    // MARK: - Body
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tab.view(
                    messageStore: messageStore,
                    vectorStoreViewModel: vectorStoreViewModel,
                    selectedTab: $selectedTab
                )
                .tabItem {
                    Label(tab.label, systemImage: tab.systemImage)
                }
                .tag(tab)
                #if DEBUG
                    .onAppear {
                        print("\(tab.label) tab appeared")
                    }
                #endif
            }
        }
        .sheet(item: $selectedAssistant) { assistant in
            NavigationView {
                ChatView(assistant: assistant, messageStore: messageStore)
            }
        }
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView(
            selectedAssistant: .constant(nil),
            vectorStoreViewModel: VectorStoreManagerViewModel(),
            messageStore: MessageStore()
        )
    }
}
