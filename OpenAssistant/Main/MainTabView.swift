import Foundation
import Combine
import SwiftUI

// MARK: - MainTabView
struct MainTabView: View {
    // MARK: - Properties
    @Binding var selectedAssistant: Assistant?
    @ObservedObject var vectorStoreViewModel: VectorStoreManagerViewModel
    @ObservedObject var messageStore: MessageStore
    
    // MARK: - Body
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

// MARK: - Tab Enum
private enum Tab: String, CaseIterable {
    // MARK: Tab Cases
    case assistants
    case manage
    case vectorStores
    case settings
    
    // MARK: UI Properties
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
    
    // MARK: View Builder
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
