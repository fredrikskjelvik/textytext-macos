import Foundation
import RealmSwift

final class FolderDB: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true)
    var id: ObjectId
    
    @Persisted
    var name: String = "New Folder"
    
    @Persisted
    var createdAt: Date = Date()
    
    @Persisted
    var updatedAt: Date = Date()
    
    @Persisted
    var parent: ObjectId?

    @Persisted
    var ancestors: List<ObjectId>

    @Persisted(originProperty: "folder")
    var document: LinkingObjects<DocumentDB>
    
    convenience init(name: String, parent: ObjectId? = nil) {
        self.init()
        self.name = name
        self.parent = parent
    }

    convenience init(id: ObjectId, name: String, parent: ObjectId? = nil) {
        self.init()
        self.id = id
        self.name = name
        self.parent = parent
    }
}
