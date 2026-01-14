import Foundation
import RealmSwift

/// The Notes associated with a ``DocumentDB``.
final class NoteDB: EmbeddedObject {
    @Persisted
    var id: ObjectId = ObjectId.generate()
    
    @Persisted
    var configuration: Map<String, AnyRealmValue> = Map()
    
    @Persisted
    var noteChapters: List<NoteChapterDB>
    
    @Persisted(originProperty: "note")
    var document: LinkingObjects<DocumentDB>
}

enum NoteDBConfigurationKey: String {
    case darkmode = "darkmode"
    case markdownmode = "markdownmode"
}
