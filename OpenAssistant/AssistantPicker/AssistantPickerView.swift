import Foundation
import Combine
import SwiftUI

struct AssistantPickerView: View {
    @StateObject private var viewModel = AssistantPickerViewModel()
    @ObservedObject var messageStore: MessageStore

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage)
                } else {
                    assistantList
                }
            }
            .navigationTitle("Select Assistant")
            .sheet(item: $viewModel.selectedAssistant) { assistant in
                ChatView(assistant: assistant, messageStore: messageStore)
            }
        }
    }
    
    private var assistantList: some View {
        List(viewModel.assistants) { assistant in
            Button(action: {
                viewModel.selectAssistant(assistant)
            }) {
                HStack {
                    Text(assistant.name)
                        .font(.headline)
                        .padding(.vertical, 6) // Increased vertical padding for easier tapping
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8) // Added horizontal padding to increase tappable area
                .contentShape(Rectangle()) // Ensures the whole area is tappable
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listStyle(InsetGroupedListStyle())
    }
}

struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.red)
                .padding(.bottom, 10)
            Text(message)
                .font(.body)
                .foregroundColor(.red)
                .padding()
            Button("Retry") {
                // Add retry action here
            }
            .padding(.top, 10)
        }
    }
}

struct AssistantPickerView_Previews: PreviewProvider {
    static var previews: some View {
        AssistantPickerView(messageStore: MessageStore())
    }
}
