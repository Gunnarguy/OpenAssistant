import SwiftUI

// The single source of truth for all tabs in the app
public enum Tab: String, CaseIterable {
    // MARK: Tab Cases
    case assistants
    case manage
    case vectorStores
    case settings

    // MARK: UI Properties
    public var label: String {
        switch self {
        case .assistants: return "Assistants"
        case .manage: return "Manage"
        case .vectorStores: return "Vector Stores"
        case .settings: return "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .assistants: return "person.3"
        case .manage: return "person.2.badge.gearshape"
        case .vectorStores: return "folder"
        case .settings: return "gear"
        }
    }

    // MARK: View Builder
    @MainActor @ViewBuilder
    func view(
        messageStore: MessageStore,
        vectorStoreViewModel: VectorStoreManagerViewModel,
        selectedTab: Binding<Tab>
    ) -> some View {
        switch self {
        case .assistants:
            // Pass the binding to the AssistantPickerView
            AssistantPickerView(messageStore: messageStore, selectedTab: selectedTab)
        case .manage:
            AssistantManagerView()
        case .vectorStores:
            VectorStoreListView(viewModel: vectorStoreViewModel)
        case .settings:
            SettingsView()
        }
    }
}
