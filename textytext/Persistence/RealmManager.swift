import Foundation
import RealmSwift
import PDFKit

/// Singleton class with a property with an instance of Realm, so that the same instance of Realm can be accessed anywhere.
/// Also does/can contain otther things, like adding dummy data.
class RealmManager {
    let realm: Realm
    
    init() {
        do {
            let config = Realm.Configuration(deleteRealmIfMigrationNeeded: true)
            self.realm = try Realm(configuration: config)
        }
        catch let error as NSError {
            fatalError(error.localizedDescription)
        }
    }
}
