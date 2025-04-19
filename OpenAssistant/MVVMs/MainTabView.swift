import Combine
import Foundation
import SwiftUI

// MARK: - MainTabView
struct MainTabView: View {
    // MARK: - Properties
    @Binding var selectedAssistant: Assistant?
    @ObservedObject var vectorStoreViewModel: VectorStoreManagerViewModel
    @ObservedObject var messageStore: MessageStore

    // Store API key and response VM
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""
    @StateObject private var responseVM: ResponseViewModel

    // Custom init to set up ResponseViewModel
    init(
        selectedAssistant: Binding<Assistant?>,
        vectorStoreViewModel: VectorStoreManagerViewModel,
        messageStore: MessageStore
    ) {
        self._selectedAssistant = selectedAssistant
        self.vectorStoreViewModel = vectorStoreViewModel
        self.messageStore = messageStore
        // Load API key from storage
        let storedKey = UserDefaults.standard.string(forKey: "OpenAI_API_Key") ?? ""
        // Initialize ResponseViewModel
        _responseVM = StateObject(
            wrappedValue: ResponseViewModel(service: OpenAIService(apiKey: storedKey)))
    }

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
            // Add Responses tab
            ResponseView(viewModel: responseVM)
                .tabItem { Label("Responses", systemImage: "doc.text") }
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
    func view(messageStore: MessageStore, vectorStoreViewModel: VectorStoreManagerViewModel)
        -> some View
    {
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
