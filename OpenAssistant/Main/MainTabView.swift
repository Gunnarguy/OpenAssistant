import Foundation
import Combine
import SwiftUI

struct MainTabView: View {
    @Binding var selectedAssistant: Assistant?
    @ObservedObject var messageStore: MessageStore
    
    var body: some View {
        TabView {
            createTab(view: AssistantPickerView(messageStore: messageStore), label: "Assistants", systemImage: "person.3")
            createTab(view: AssistantManagerView(), label: "Manage", systemImage: "person.2.badge.gearshape")
            createTab(view: VectorStoreListView(viewModel: VectorStoreManagerViewModel()), label: "Vector Stores", systemImage: "folder")
            createTab(view: SettingsView(), label: "Settings", systemImage: "gear")
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
