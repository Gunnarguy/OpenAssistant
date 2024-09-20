import Foundation
import Combine
import SwiftUI

struct AssistantManagerView: View {
    @StateObject private var viewModel = AssistantManagerViewModel()
    @State private var showingCreateAssistantSheet = false

    var body: some View {
        NavigationView {
            assistantList
                .navigationTitle("Manage Assistants")
                .toolbar {
                    addButton
                }
        }
        .onAppear(perform: viewModel.fetchAssistants)
        .onReceive(NotificationCenter.default.publisher(for: .assistantCreated)) { notification in
            handleAssistantCreated(notification: notification)
        }
        .sheet(isPresented: $showingCreateAssistantSheet) {
            CreateAssistantView(viewModel: viewModel)
        }
    }

    private var assistantList: some View {
        List(viewModel.assistants) { assistant in
            NavigationLink(destination: AssistantDetailView(assistant: assistant, managerViewModel: viewModel)) {
                Text(assistant.name)
                    .font(.body)
                    .padding(.vertical, 6)
            }
        }
    }

    private var addButton: some View {
        Button(action: { showingCreateAssistantSheet.toggle() }) {
            Image(systemName: "plus")
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