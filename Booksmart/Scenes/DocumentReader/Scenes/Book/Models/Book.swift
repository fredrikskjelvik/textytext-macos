import Foundation

struct Book: Codable {
    var format: BookFormat
    var file: String
    var numPages: Int = 0
    
    func getURL() -> URL? {
        guard let url = Bundle.main.url(forResource: file, withExtension: format.rawValue) else {
            return nil
        }
        
        return url
    }
    
    enum CodingKeys: String, CodingKey {
        case format
        case file
        case numPages = "num_pages"
    }
}

enum BookFormat: String, Codable {
    case pdf, epub
}
