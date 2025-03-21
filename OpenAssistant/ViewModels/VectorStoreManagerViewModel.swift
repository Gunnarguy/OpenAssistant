import Foundation
import Combine

class VectorStoreManagerViewModel: BaseViewModel {
    @Published var vectorStores: [VectorStore] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let openAIService: OpenAIService
    private var fetchStoresCancellable: AnyCancellable?
    
    // Use dependency injection to pass the shared service
    init(openAIService: OpenAIService) {
        self.openAIService = openAIService
        super.init()
        print("VectorStoreManagerViewModel initialized with injected service")
    }
    
    // Prevent multiple fetch calls in quick succession
    private var lastFetchTime: Date?
    private let minFetchInterval: TimeInterval = 5 // seconds
    
    func fetchVectorStores() {
        // If we fetched recently, don't fetch again
        if let lastTime = lastFetchTime, Date().timeIntervalSince(lastTime) < minFetchInterval {
            print("Skipping fetch - called too frequently")
            return
        }
        
        guard !isLoading else {
            print("Fetch already in progress, skipping")
            return
        }
        
        isLoading = true
        lastFetchTime = Date()
        
        fetchStoresCancellable = openAIService.fetchVectorStores()
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                
                switch completion {
                case .finished:
                    self.errorMessage = nil
                case .failure(let error):
                    self.errorMessage = "Failed to fetch vector stores: \(error.localizedDescription)"
                    print("Error fetching vector stores: \(error)")
                }
            }, receiveValue: { [weak self] stores in
                guard let self = self else { return }
                self.vectorStores = stores
                print("Successfully fetched vector stores.")
            })
            
        // Add the cancellable to your collection to prevent it from being deallocated
        storeCancellable(fetchStoresCancellable)
    }
    
    // Other vector store management methods...
}
