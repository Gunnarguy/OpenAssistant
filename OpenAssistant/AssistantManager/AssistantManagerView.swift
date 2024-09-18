import Foundation
import Combine
import SwiftUI

struct AssistantManagerView: View {
    @StateObject private var viewModel = AssistantManagerViewModel()
    @State private var showingCreateAssistantSheet = false
    
    var body: some View {
        NavigationView {
            List(viewModel.assistants) { assistant in
                NavigationLink(destination: AssistantDetailView(assistant: assistant)) {
                    Text(assistant.name)
                        .font(.body)
                        .padding(.vertical, 6)
                }
            }
            .navigationTitle("Manage Assistants")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateAssistantSheet.toggle() }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear(perform: viewModel.fetchAssistants)
        .onReceive(NotificationCenter.default.publisher(for: .assistantCreated), perform: handleAssistantCreated)
        .sheet(isPresented: $showingCreateAssistantSheet) {
            CreateAssistantView(viewModel: viewModel)
        }
    }
    
    private func handleAssistantCreated(notification: Notification) {
        if let createdAssistant = notification.object as? Assistant {
            viewModel.assistants.append(createdAssistant)
        }
    }
}

struct AssistantManagerView_Previews: PreviewProvider {
    static var previews: some View {
        AssistantManagerView()
    }
}
