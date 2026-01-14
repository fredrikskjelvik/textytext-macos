import Foundation
import RealmSwift

/// Make URL type storeable in Realm objects. Store as string under the hood.
extension URL: FailableCustomPersistable {
    public typealias PersistedType = String
    
    public init?(persistedValue: String) { self.init(string: persistedValue) }
    
    public var persistableValue: String { self.absoluteString }
}
