import Foundation
import Combine
import SwiftUI

struct MainTabView: View {
    @Binding var selectedAssistant: Assistant?
    @ObservedObject var vectorStoreViewModel: VectorStoreManagerViewModel
    @ObservedObject var messageStore: MessageStore
    
    var body: some View {
        TabView {
            ForEach(Tab.allCases, id: \.self) { tab in
                tab.view(messageStore: messageStore, vectorStoreViewModel: vectorStoreViewModel)
                    .tabItem {
                        Label(tab.label, systemImage: tab.systemImage)
                    }
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

private enum Tab: CaseIterable {
    case assistants
    case manage
    case vectorStores
    case settings
    
    var label: String {
        switch self {
        case .assistants: return "Assistants"
        case .manage: return "Manage"
        case .vectorStores: return "Vector Stores"
        case .settings: return "Settings"
        }
    }
    
    var systemImage: String {
        switch self {
        case .assistants: return "person.3"
        case .manage: return "person.2.badge.gearshape"
        case .vectorStores: return "folder"
        case .settings: return "gear"
        }
    }
    
    @MainActor @ViewBuilder
    func view(messageStore: MessageStore, vectorStoreViewModel: VectorStoreManagerViewModel) -> some View {
        switch self {
        case .assistants:
            AssistantPickerView(messageStore: messageStore)
        case .manage:
            AssistantManagerView()
        case .vectorStores:
            VectorStoreListView(viewModel: vectorStoreViewModel)
        case .settings:
            SettingsView()
        }
    }
}
