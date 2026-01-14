import Foundation
import PDFKit
import RealmSwift

/// A nitem in the table of contents.
///
/// This is the class that is used in the UI, whereas `OutlineItemDB` is used for persistence.
class OutlineItem: Equatable, Identifiable {
    var id: ObjectId {
        return realmObject.id
    }
    var realmObject: OutlineItemDB
    var parent: OutlineItem?
    var label: String
    var page: Int
    var chapter: Chapter
    var children: [OutlineItem] = []
    /// This is used in OutlineGroup, where the type needs to be optional
    var _children: [OutlineItem]? { children }
    
    init(realmObject: OutlineItemDB, children: [OutlineItem] = [], parent: OutlineItem? = nil) {
        self.realmObject = realmObject
        self.label = realmObject.label
        self.page = realmObject.page
        self.chapter = realmObject.chapter
        self.parent = parent
        self.children = children
    }
    
    func getPrefix() -> String {
        return chapter.getPrefix()
    }
    
    var numberOfChildren: Int {
        return children.count
    }
    
    /// The chapter based implementation is simple, should never have an unexpected error, and works as long as the chapter indexes are always correctly initialized.
    /// For now I assume that is the case.
    var index: Int {
        return chapter.indexes.last!
    }
    
    func child(at index: Int) -> OutlineItem? {
        return children[safe: index]
    }
    
    func insertChild(_ item: OutlineItem) {
        children.append(item)
    }

    func printOutline() {
        print(chapter.getPrefix() + " " + label)
        
        for child in children {
            child.printOutline()
        }
    }
    
    /// Deep copy an outline item
    static func copy(_ root: OutlineItem) -> OutlineItem {
        var children = [OutlineItem]()
        
        for child in root.children {
            child.parent = root
            children.append(OutlineItem.copy(child))
        }
        
        let val = OutlineItem(realmObject: root.realmObject, children: children, parent: root.parent)
        
        return val
    }
    
    // TODO: Have to make changes like these reflected in realmObject. Either in a didSet thing, or more likely in a controlled method like this,
    // to prevent having to run inside try block every time.
    func performCleanup(_ chapter: [Int]? = nil) {
        let chapter = chapter ?? self.chapter.indexes
        
        self.chapter.indexes = chapter
        
        for (idx, child) in children.enumerated() {
            child.performCleanup(chapter + [idx])
        }
    }
    
    // MARK: Conformance to Equatable
    
    static func ==(lhs: OutlineItem, rhs: OutlineItem) -> Bool {
        return lhs.realmObject.id == rhs.realmObject.id
    }
    
}
