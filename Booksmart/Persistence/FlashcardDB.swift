import Foundation
import RealmSwift

final class FlashcardDB: EmbeddedObject, Persister {
    
    @Persisted
    var id: ObjectId = ObjectId.generate()
    
    @Persisted
    var createdAt: Date = Date()
    
    @Persisted
    var updatedAt: Date = Date()
    
    @Persisted
    var question: CodedTextViewContents? = nil
    
    @Persisted
    var hint: CodedTextViewContents? = nil
    
    @Persisted
    var answer: CodedTextViewContents? = nil
    
    @Persisted
    var outlineItem: OutlineItemDB? = nil
    
    @Persisted
    var page: Int?
    
    @Persisted
    var tags: List<String>
    
    @Persisted(originProperty: "flashcards")
    var document: LinkingObjects<DocumentDB>
    
}
