import Foundation
import RealmSwift

/// A document (i.e. notes, flashcards and (optionally) a book)
final class DocumentDB: Object, ObjectKeyIdentifiable {
    
    @Persisted(primaryKey: true)
    var id: ObjectId
    
    @Persisted
    var name: String = "New Document"
    
    @Persisted
    var createdAt: Date = Date()
    
    @Persisted
    var updatedAt: Date = Date()
    
    @Persisted
    var book: BookDB?
    
    @Persisted
    var note: NoteDB?
    
    @Persisted
    var flashcards: List<FlashcardDB>
    
    @Persisted
    var outlineItems: List<OutlineItemDB>

    @Persisted
    var folder: FolderDB?

    @Persisted
    var favourite: Bool = false

    convenience init(name: String) {
        self.init()
        self.name = name
    }
    
    func getOutlineItemsContainer() -> OutlineContainer {
        return OutlineContainerFactory.createFromRealmObjects(Array(outlineItems))
    }
   
}
