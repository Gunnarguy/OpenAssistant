import SwiftUI
import Combine

// MARK: - ChatView
struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    @Environment(\.colorScheme) var colorScheme

    init(assistant: Assistant, messageStore: MessageStore) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(assistant: assistant, messageStore: messageStore))
        self.messageStore = messageStore
    }

    var body: some View {
        NavigationView {
            ChatContentView(viewModel: viewModel, messageStore: messageStore, colorScheme: colorScheme)
                .navigationTitle(viewModel.assistant.name)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: ChatHistoryView(messages: messageStore.messages, assistantId: viewModel.assistant.id)) {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .alert(item: $viewModel.errorMessage) { errorMessage in
                    Alert(title: Text("Error"), message: Text(errorMessage.message), dismissButton: .default(Text("OK")))
                }
        }
    }
}

// MARK: - ChatContentView
struct ChatContentView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    var colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(viewModel: viewModel, colorScheme: colorScheme)
            Spacer()
            InputView(viewModel: viewModel, messageStore: messageStore, colorScheme: colorScheme)
                .padding(.horizontal)
            StepCounterView(stepCounter: viewModel.stepCounter)
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
        .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all))
    }
}

// MARK: - MessageListView
struct MessageListView: View {
    @ObservedObject var viewModel: ChatViewModel
    var colorScheme: ColorScheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageView(message: message, colorScheme: colorScheme)
                    }
                    if viewModel.isLoading {
                        NewCustomLoadingIndicator()
                            .padding(.vertical, 10)
                            .id("loadingIndicator")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: viewModel.messages) { _ in
                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
                .onChange(of: viewModel.isLoading) { _ in
                    if viewModel.isLoading {
                        proxy.scrollTo("loadingIndicator", anchor: .bottom)
                    }
                }
            }
            .onAppear {
                viewModel.scrollViewProxy = proxy
                viewModel.createThread()
                viewModel.scrollToLastMessage()
            }
            .background(Color.clear)
        }
    }
}

// MARK: - InputView
struct InputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    var colorScheme: ColorScheme

    var body: some View {
        HStack {
            NavigationLink(destination: ChatHistoryView(messages: messageStore.messages, assistantId: viewModel.assistant.id)) {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                    .padding(14)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(25)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
            }
            TextField("Type a message", text: $viewModel.inputText, onCommit: viewModel.sendMessage)
                .padding(16)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(25)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.blue, lineWidth: 1)
                )
            SendButton(viewModel: viewModel, messageStore: messageStore)
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
}

// MARK: - SendButton
struct SendButton: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore

    var body: some View {
        Button(action: sendMessageAction) {
            Image(systemName: "paperplane.fill")
                .foregroundColor(viewModel.inputText.isEmpty || viewModel.isLoading ? .gray : .white)
                .padding(16)
                .background(viewModel.inputText.isEmpty || viewModel.isLoading ? Color.gray.opacity(0.6) : Color.blue)
                .cornerRadius(25)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
        }
        .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
    }

    private func sendMessageAction() {
        viewModel.sendMessage()
        if let lastMessage = viewModel.messages.last {
            messageStore.addMessage(lastMessage)
        }
    }
}

// MARK: - StepCounterView
struct StepCounterView: View {
    let stepCounter: Int

    var body: some View {
        if FeatureFlags.enableNewFeature {
            Text("Step: \(stepCounter)")
                .font(.footnote)
                .foregroundColor(.gray)
        } else {
            EmptyView()
        }
    }
}

// MARK: - MessageView
struct MessageView: View {
    let message: Message
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            Text(message.content.first?.text?.value ?? "")
                .padding(16)
                .background(message.role == .user ? Color.blue.opacity(0.85) : Color(UIColor.systemGray5))
                .cornerRadius(16)
                .foregroundColor(message.role == .user ? .white : (colorScheme == .dark ? .white : .black))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
            if message.role != .user {
                Spacer()
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - ChatHistoryView
struct ChatHistoryView: View {
    let messages: [Message]
    let assistantId: String

    var body: some View {
        List(filteredMessages) { message in
            VStack(alignment: .leading) {
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.headline)
                Text(message.content.first?.text?.value ?? "")
                    .font(.body)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Chat History")
    }

    private var filteredMessages: [Message] {
        messages.filter { $0.assistant_id == assistantId }
    }
}

// MARK: - NewCustomLoadingIndicator
struct NewCustomLoadingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        VStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(AngularGradient(gradient: Gradient(colors: [.blue.opacity(0.6), .green.opacity(0.6), .blue.opacity(0.6)]), center: .center), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 30, height: 30)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
        }
    }
}

// MARK: - ErrorMessage
struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - ChatView Previews
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        let assistant = Assistant(
            id: "1",
            object: "assistant",
            created_at: Int(Date().timeIntervalSince1970),
            name: "Test Assistant",
            description: "This is a test assistant.",
            model: "test-model",
            instructions: nil,
            threads: nil,
            tools: [],
            top_p: 1.0,
            temperature: 0.7,
            tool_resources: nil,
            metadata: nil,
            response_format: nil,
            file_ids: [] // Provide an empty array or appropriate file IDs
        )
        let messageStore = MessageStore()
        ChatView(assistant: assistant, messageStore: messageStore)
    }
}
