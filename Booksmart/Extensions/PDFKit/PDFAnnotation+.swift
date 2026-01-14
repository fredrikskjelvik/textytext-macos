import PDFKit
import RealmSwift

extension PDFAnnotation {
    var subtype: PDFAnnotationSubtype {
        return PDFAnnotationSubtype.init(rawValue: "/" + self.type!)
    }
    
    func toHighlight() -> PDFHighlightAnnotation? {
        guard subtype == .highlight else { return nil }
        
        return PDFHighlightAnnotation(bounds: bounds, color: color, page: page)
    }
}

/// A PDFAnnotation that is a highlight. Contains a simplified initialized and a way to encode/decode highlights so they can be stored in database.
class PDFHighlightAnnotation: PDFAnnotation {
    
    init(bounds: CGRect, color: NSColor, page: PDFPage? = nil) {
        super.init(
            bounds: bounds,
            forType: PDFAnnotationSubtype.highlight,
            withProperties: [
                PDFAnnotationKey.highlightingMode: PDFAnnotationHighlightingMode.push
            ]
        )
        
        self.color = color
        self.page = page
    }
    
    func getCoded() -> CodedAnnotation {
        return CodedAnnotation(page: page?.pageNumber ?? -1, bounds: bounds, color: color)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    struct CodedAnnotation: Codable, FailableCustomPersistable {
        let page: Int
        let bounds: CGRect
        let color: NSColor
        
        init(page: Int, bounds: CGRect, color: NSColor) {
            self.page = page
            self.bounds = bounds
            self.color = color
        }
        
        // MARK: Conform to Codable
        
        private enum Keys: CodingKey {
            case page
            case bounds
            case color
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            
            self.page = try container.decode(Int.self, forKey: Keys.page)
            self.bounds = try container.decode(CGRect.self, forKey: Keys.bounds)
            let decodedColor = try container.decode(Data.self, forKey: Keys.color)
            self.color = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(decodedColor) as? NSColor ?? NSColor.systemCyan
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Keys.self)
            
            try container.encode(page, forKey: Keys.page)
            try container.encode(bounds, forKey: Keys.bounds)
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
            try container.encode(colorData, forKey: Keys.color)
        }
        
        // MARK: Conform to FailableCustomPersistable
        
        public typealias PersistedType = Data
        
        public init?(persistedValue: Data) {
            guard let decoded = try? JSONDecoder().decode(CodedAnnotation.self, from: persistedValue) else { return nil }
            
            self.init(page: decoded.page, bounds: decoded.bounds, color: decoded.color)
        }
        
        public var persistableValue: Data {
            return try! JSONEncoder().encode(self)
        }
    }
}
