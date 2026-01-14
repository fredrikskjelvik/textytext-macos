import Foundation
import RealmSwift

/// Database object for an outline item in a document.
///
/// The outline items are extracted from the uploaded ebook and potentially edited and rearranged by the user when a document is created.
/// The outline items that are shown in the side panel, as well as in the notes and flashcards are taken from the Realm database (this object).
/// I.e. the book's outline item (e.g. PDFOutline class in TextKit) is not used (only during document creation)
final class OutlineItemDB: EmbeddedObject {
    
    @Persisted
    var id: ObjectId
    
    @Persisted
    var label: String
    
    @Persisted
    var page: Int
    
    @Persisted
    var chapter: Chapter
    
    @Persisted(originProperty: "outlineItems")
    var document: LinkingObjects<DocumentDB>
    
    convenience init(label: String, page: Int, chapter: Chapter) {
        self.init()
        self.id = ObjectId.generate()
        self.label = label
        self.page = page
        self.chapter = chapter
    }
    
}
