import Foundation
import PDFKit
import RealmSwift

/// Factory for `OutlineContainer`. Can create an OutlineContainer from realm database contents or PDF document metadata.
struct OutlineContainerFactory {
    
    /// Initialize an OutlineContainer from Realm contents
    static func createFromRealmObjects(_ realmObjects: [OutlineItemDB]) -> OutlineContainer {
        guard let rootRealmObject = realmObjects.first(where: { $0.chapter.isRoot() }) else {
            fatalError("Tried to convert outline items to hierarchy, but there is no root item in the database.")
        }
        
        let rootOutlineItem = hierarchyRecursion(item: OutlineItem(realmObject: rootRealmObject), items: realmObjects)
        
        return OutlineContainer(root: rootOutlineItem)
    }
    
    /// Initialize an OutlineContainer from PDFKit's PDFOutline. Currently has optional return type (despite never failing), but in future it will, when checks are added
    /// - Parameter pdfOutlineRoot: outline root from PDFKit
    static func createFromPdfDocument(_ pdfOutlineRoot: PDFOutline) -> OutlineContainer? {
        let rootOutlineItem = hierarchyRecursion(item: pdfOutlineRoot, chapter: Chapter([]))
        
        rootOutlineItem.label = "Root"
        rootOutlineItem.page = 0
        
        return OutlineContainer(root: rootOutlineItem)
    }
    
    static func copyRoot(outline: OutlineContainer) -> OutlineItem {
        return OutlineItem.copy(outline.root)
    }
}

/// Turn a list of realm outline item objects into a tree representation
/// - Parameters:
///   - item: when calling this method, this item should be the root outline item (realm object)
///   - items: all realm outline item objects
/// - Returns: the root outline item with all children and children of children etc.
func hierarchyRecursion(item: OutlineItem, items: [OutlineItemDB]) -> OutlineItem {
    let currentChapter = item.chapter.indexes
    let depth = item.chapter.depth()

    let posterity = items.filter({
        let comparisonChapter = $0.chapter.indexes
        
        if currentChapter.count > comparisonChapter.count {
            return false
        }
        
        return Array(comparisonChapter[0..<currentChapter.count]) == currentChapter
    })

    let children = posterity.filter({
        let comparisonChapter = $0.chapter.indexes
        
        if currentChapter.count > comparisonChapter.count {
            return false
        }
        
        return comparisonChapter.count == depth + 1
    })
    
    if children.count > 0
    {
        for child in children
        {
            let childOutlineItem = OutlineItem(realmObject: child)
                childOutlineItem.parent = item
            item.insertChild(hierarchyRecursion(item: childOutlineItem, items: posterity))
        }
    }
    
    return item
}

/// Create outlineItem root from PDFKit's PDFOutline. Problem: Am not able to set parent property, have to do that in separate recursive function.
/// - Parameters:
///   - item: pdf outline item
///   - chapter: keep track of chapter at each recursion level, and set it
/// - Returns: Outline Item root
func hierarchyRecursion(item: PDFOutline, chapter: Chapter) -> OutlineItem {
    var children = [OutlineItem]()
    
    for i in 0..<item.numberOfChildren
    {
        let nextChapter = Chapter(chapter.indexes + [i])
        
        children.append(hierarchyRecursion(item: item.child(at: i)!, chapter: nextChapter) )
    }
    
    let realmObject = pdfOutlineToRealm(outline: item, chapter: chapter)
    
    let outlineItem = OutlineItem(realmObject: realmObject, children: [], parent: nil)
    
    for child in children {
        child.parent = outlineItem
    }
    
    outlineItem.children = children
    
    return outlineItem
}
    
func pdfOutlineToRealm(outline: PDFOutline, chapter: Chapter) -> OutlineItemDB {
    var label = outline.label ?? "???"
    label = label == "" ? "???" : label
    
    return OutlineItemDB(label: label, page: outline.getPage(), chapter: chapter)
}
