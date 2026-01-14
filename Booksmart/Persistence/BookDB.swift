import Foundation
import RealmSwift
import PDFKit

/// Realm object for an ebook associated with a particular ``DocumentDB``
final class BookDB: EmbeddedObject {
    
    @Persisted
    var id: ObjectId
    
    @Persisted
    var name: String
    
    @Persisted
    var format: BookFormatRealm
    
    /// Name of the file in (local) storage
    @Persisted
    var fileName: String
    
    /// Return a `PDFDocument` for this book
    func getPDFDocument() -> PDFDocument? {
        guard
            let storage = try? LocalStorageHandler(),
            let data = try? storage.getBook(fileName: fileName)
        else { return nil }
        
        return PDFDocument(data: data)
    }
    
    // TODO: Add document attributes, e.g. title, publisher, year published, number of pages.
    // Use something like this: pdfDocument?.getMetadata(attributeKey: PDFDocumentAttribute.authorAttribute)
    // and save it in a dictionary (Realm can store dictionaries)
    
    /// Number of pages in this book
    @Persisted
    var pages: Int
    
    @Persisted(originProperty: "book")
    var document: LinkingObjects<DocumentDB>
    
    /// All highlights in the PDF
    ///
    /// ``PDFHighlightAnnotation/CodedAnnotation`` conforms to FailableCustomPersistable. This property actually stores
    /// a list of Data objects, but we can access it like a list of ``PDFHighlightAnnotation/CodedAnnotation``
    @Persisted
    var highlights: List<PDFHighlightAnnotation.CodedAnnotation>
    
    /// List of page indexes for pages that are bookmarked
    @Persisted
    var bookmarks: List<Int>
    
    /// Check if page has bookmark
    func hasBookmark(at page: Int) -> Bool {
        return bookmarks.contains(where: { $0 == page })
    }
    
    convenience init(name: String, format: BookFormatRealm, fileName: String, pages: Int) {
        self.init()
        self.id = ObjectId.generate()
        self.name = name
        self.format = format
        self.fileName = fileName
        self.pages = pages
    }
}

enum BookFormatRealm: String, Equatable, PersistableEnum {
    case pdf, epub
}
