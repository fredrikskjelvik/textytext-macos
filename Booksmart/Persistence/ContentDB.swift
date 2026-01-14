import RealmSwift

final class ContentDB: Object, ObjectKeyIdentifiable {
    
    @Persisted(primaryKey: true)
    var id: ObjectId
    
    @Persisted
    var contents: CodedTextViewContents?
    
    convenience init(contents: CodedTextViewContents?) {
        self.init()
        self.id = ObjectId.generate()
        self.contents = contents
    }
    
}
