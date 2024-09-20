import SwiftUI

struct ContentView: View {
    @State private var selectedAssistant: Assistant?
    @State private var isLoading = false
    @StateObject private var messageStore = MessageStore()

    var body: some View {
        ZStack {
            MainTabView(selectedAssistant: $selectedAssistant, messageStore: messageStore)
            if isLoading {
                LoadingView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isLoading = false
                        }
                    }
            }
        }
        .onAppear {
            print("ContentView appeared")
        }
    }
}

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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct LoadingView: View {
    var body: some View {
        VStack {
            Text("Loading...")
                .font(.largeTitle)
                .foregroundColor(.blue)
                .padding()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.8))
        .edgesIgnoringSafeArea(.all)
    }
}
