import Foundation
import RealmSwift

/// Make Chapter type storeable in Realm objects. Store as string under the hood.
extension Chapter: FailableCustomPersistable {
    static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        return lhs.indexes == rhs.indexes
    }
    
    public typealias PersistedType = String

    public init?(persistedValue: String) {
        let chapters = persistedValue.split(separator: ",").map { Int($0)! }
        self.init(chapters)
    }

    public var persistableValue: String {
        return self.indexes.map(String.init).joined(separator: ",")
    }
}
