import Foundation

struct BookListing: Codable, Hashable {
    let title: String
    let description: String
    let price: Int
    let discountPercentage: Double
    let category: String
    let thumbnail: String
    
    private enum CodingKeys: String, CodingKey {
        case title
        case description
        case price
        case discountPercentage
        case category
        case thumbnail
    }
}

extension BookListing {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try values.decode(String.self, forKey: .title)
        description = try values.decode(String.self, forKey: .description)
        price = try values.decode(Int.self, forKey: .price)
        discountPercentage = try values.decode(Double.self, forKey: .discountPercentage)
        category = try values.decode(String.self, forKey: .category)
        thumbnail = try values.decode(String.self, forKey: .thumbnail)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(price, forKey: .price)
        try container.encode(discountPercentage, forKey: .discountPercentage)
        try container.encode(category, forKey: .category)
        try container.encode(thumbnail, forKey: .thumbnail)
    }
}


