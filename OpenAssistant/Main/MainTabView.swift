import Foundation
import Combine
import SwiftUI

struct MainTabView: View {
    @Binding var selectedAssistant: Assistant?
    @ObservedObject var messageStore: MessageStore
    
    var body: some View {
        TabView {
            ForEach(Tab.allCases, id: \.self) { tab in
                createTab(view: tab.view(messageStore: messageStore), label: tab.label, systemImage: tab.systemImage)
            }
        }
        .sheet(item: $selectedAssistant) { assistant in
            NavigationView {
                ChatView(assistant: assistant, messageStore: messageStore)
            }
        }
    }
    
    @ViewBuilder
    private func createTab<Content: View>(view: Content, label: String, systemImage: String) -> some View {
        view
            .tabItem {
                Label(label, systemImage: systemImage)
            }
            .onAppear {
                print("\(label) tab appeared")
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
    func view(messageStore: MessageStore) -> some View {
        switch self {
        case .assistants:
            AssistantPickerView(messageStore: messageStore)
        case .manage:
            AssistantManagerView()
        case .vectorStores:
            VectorStoreListView(viewModel: VectorStoreManagerViewModel())
        case .settings:
            SettingsView()
        }
    }
}
