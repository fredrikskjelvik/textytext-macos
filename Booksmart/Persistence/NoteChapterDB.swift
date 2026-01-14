import RealmSwift

/// The contents of one chapter/subchapter in the notes document.
final class NoteChapterDB: EmbeddedObject {
    
    @Persisted
    var id: ObjectId
    
    @Persisted
    var outlineItem: OutlineItemDB? = nil
    
    @Persisted
    var contents: CodedTextViewContents?
    
    @Persisted(originProperty: "noteChapters")
    var note: LinkingObjects<NoteDB>
    
    convenience init(outlineItem: OutlineItemDB, contents: CodedTextViewContents?) {
        self.init()
        self.id = ObjectId.generate()
        self.outlineItem = outlineItem
        self.contents = contents
    }
    
}
