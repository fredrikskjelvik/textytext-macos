import Foundation

// TODO: Make identifiable
// TODO: Rename to Document
struct Note: Codable {
	var id = UUID()
	var name: String
	var book: Book
	
	init(name: String, format: BookFormat, file: String) {
		self.name = name
		self.book = Book(format: format, file: file)
	}
    
    enum CodingKeys: String, CodingKey {
        case name
        case book
    }
}
