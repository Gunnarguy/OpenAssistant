import Combine
import Foundation

@MainActor
class ResponseViewModel: ObservableObject {
    @Published var model: String = "o3-mini"  // default model
    @Published var inputText: String = ""
    @Published var response: ResponseResult?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    private let service: OpenAIService
    private var cancellables = Set<AnyCancellable>()

    init(service: OpenAIService) {
        self.service = service
    }

    /// Send a createResponse request
    func sendRequest() {
        guard !inputText.isEmpty else { return }
        isLoading = true
        // Build request with default advanced options
        let request = ResponseRequest(
            model: model,
            input: inputText,
            temperature: nil,
            top_p: nil,
            max_output_tokens: nil,
            stream: false,
            include: nil,
            tool_choice: nil,
            parallel_tool_calls: nil
        )
        service.createResponse(request: request) {
            [weak self] (result: Result<ResponseResult, OpenAIServiceError>) in
            Task { @MainActor in
                self?.isLoading = false
                switch result {
                case .success(let resp): self?.response = resp
                case .failure(let error): self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Retrieve an existing response by ID
    func fetchResponse(by id: String) {
        isLoading = true
        service.getResponse(responseId: id) {
            [weak self] (result: Result<ResponseResult, OpenAIServiceError>) in
            Task { @MainActor in
                self?.isLoading = false
                switch result {
                case .success(let resp): self?.response = resp
                case .failure(let error): self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
