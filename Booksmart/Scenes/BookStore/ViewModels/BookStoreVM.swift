import Foundation
import Factory
import Combine

class BookStoreVM: ObservableObject {
    @Injected(Container.apiService) private var apiService
    
    init() {
        self.fetch()
    }
    
    @Published var book: BookListing? = nil

    var cancellables = Set<AnyCancellable>()
    
    private func fetch() {
        apiService.getBooks()
            .sink(receiveCompletion: { error in
                print(error)
            }, receiveValue: { [weak self] data in
                print(data)
                self?.book = data
            })
            .store(in: &cancellables)
    }
}
