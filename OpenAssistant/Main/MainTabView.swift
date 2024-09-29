import Foundation
import Combine
import SwiftUI

struct MainTabView: View {
    @Binding var selectedAssistant: Assistant?
    @ObservedObject var messageStore: MessageStore
    
    var body: some View {
        TabView {
            AssistantPickerView(messageStore: messageStore)
                .tabItem {
                    Label("Assistants", systemImage: "person.3")
                }
 
            AssistantManagerView()
                .tabItem {
                    Label("Manage", systemImage: "person.2.badge.gearshape")
                }
                .onAppear {
                    print("AssistantManagerView tab appeared")
                }
            
            VectorStoreListView(viewModel: VectorStoreManagerViewModel())
                .tabItem {
                    Label("Vector Stores", systemImage: "folder")
                }
                .onAppear {
                    print("VectorStoreListView tab appeared")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .onAppear {
                    print("SettingsView tab appeared")
                }
        }
        .sheet(item: $selectedAssistant) { assistant in
            NavigationView {
                ChatView(assistant: assistant, messageStore: messageStore)
            }
        }
    }
}
