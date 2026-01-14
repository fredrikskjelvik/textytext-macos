import Combine
import Foundation

enum APIError: Error {
    case badURL
    case failedToEncodeJson
    case makeUrlConnectionError
    case badResponse(Int)
    case unknownError
}

protocol APIService {
    func getBooks() -> AnyPublisher<BookListing, Error>
}

class APIServiceProduction: APIService {
    enum Endpoint: String {
        case getBooks = "https://dummyjson.com/products/1"
        
        var url: URL? {
            return URL(string: self.rawValue)
        }
    }
    
    public func getBooks() -> AnyPublisher<BookListing, Error> {
        guard let url = Endpoint.getBooks.url else {
            return Fail(error: APIError.badURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map({ $0.data })
            .decode(type: BookListing.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

class APIServiceTesting: APIService {
    public func getBooks() -> AnyPublisher<BookListing, Error> {
        let book = BookListing(title: "Physics", description: "Book about physics", price: 55, discountPercentage: 0.0, category: "Science", thumbnail: "")
        
        return Just(book)
            .tryMap({ $0 })
            .eraseToAnyPublisher()
    }
}
