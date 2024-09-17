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
                    Button(action: {
                        showingCreateAssistantSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetchAssistants()
        }
        .onReceive(NotificationCenter.default.publisher(for: .assistantCreated)) { notification in
            if let createdAssistant = notification.object as? Assistant {
                viewModel.assistants.append(createdAssistant)
            }
        }
        .sheet(isPresented: $showingCreateAssistantSheet) {
            CreateAssistantView(viewModel: viewModel)
        }
    }
}

struct AssistantManagerView_Previews: PreviewProvider {
    static var previews: some View {
        AssistantManagerView()
    }
}
