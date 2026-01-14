import Foundation
import RealmSwift

/// Protocol with default implementations for various operations like select, filter, etc. Realm objects can conform to this protocol to get some useful methods.
protocol Persister {
    static func select<T: Object>(type: T.Type, filter: NSPredicate?) -> Results<T>
    static func filter<T: Object>(type: T.Type, filter: @escaping ((T) -> Bool)) -> LazyFilterSequence<Results<T>>
    static func insert(object: Object, update: Bool?)
    static func insert(objects: [Object], update: Bool?)
    static func delete(object: Object)
    static func delete<T: Object>(type: T.Type, filter: NSPredicate?)
    static func deleteAll<T: Object>(type: T.Type)
    static func resetDB()
}

extension Persister {
    
    // MARK: - Read Methods
    static func select<T: Object>(type: T.Type, filter: NSPredicate? = nil) -> Results<T>  {
        do {
            let realm = try Realm()
            if let predicate = filter {
                return realm.objects(T.self).filter(predicate)
            } else {
                return realm.objects(T.self)
            }
        }  catch let error as NSError {
            fatalError("Error opening Realm: \(error)")
        }
    }
    
    // MARK: - Read Methods
    static func filter<T: Object>(type: T.Type, filter: @escaping ((T) -> Bool)) -> LazyFilterSequence<Results<T>>  {
        do {
            let realm = try Realm()
            return realm.objects(T.self).filter(filter)
        }  catch let error as NSError {
            fatalError("Error opening Realm: \(error)")
        }
    }
    
    // MARK: - Write methods
    static func insert(object: Object, update: Bool? = nil) {
        do {
            let realm = try Realm()
            try realm.write {
                if update == true {
                    realm.add(object, update: .modified)
                } else {
                    realm.add(object)
                }
            }
        }  catch let error as NSError {
            fatalError("Error opening Realm: \(error)")
        }
    }
    
    static func insert(objects: [Object], update: Bool? = nil) {
        do {
            let realm = try Realm()
            try realm.write {
                if update == true {
                    realm.add(objects, update: .modified)
                } else {
                    realm.add(objects)
                }
            }
        }  catch let error as NSError {
            fatalError("Error opening Realm: \(error)")
        }
    }
    
    static func delete(object: Object) {
        // Delete an object with a transaction
        do {
            let realm = try Realm()
            try realm.write {
                realm.delete(object)
            }
        }  catch let error as NSError {
            fatalError("Error opening Realm: \(error)")
        }
    }
    
    static func delete<T: Object>(type: T.Type, filter: NSPredicate?) {
        do {
            let realm = try Realm()
            try realm.write {
                if let predicate = filter {
                    realm.delete(realm.objects(T.self).filter(predicate))
                } else {
                    realm.delete(realm.objects(T.self))
                }
            }
        }  catch let error as NSError {
            fatalError("Error opening Realm: \(error)")
        }
    }
    
    static func resetDB() {
        // Delete an object with a transaction
        do {
            let realm = try Realm()
            try realm.write {
                realm.deleteAll()
            }
        }  catch let error as NSError {
            fatalError("Error opening Realm: \(error)")
        }
    }
    
    static func deleteAll<T: Object>(type: T.Type) {
        // Delete an object with a transaction
        do {
            let realm = try Realm()
            try realm.write {
                realm.delete(realm.objects(T.self))
            }
        }  catch let error as NSError {
            fatalError("Error opening Realm: \(error)")
        }
    }
}
