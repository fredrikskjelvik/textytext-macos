import Foundation

/// The different ways to retrieve a chapter from the table of contents in OutlineContainer
enum QueryOption {
    case previousBefore(Chapter)
    case nextAfter(Chapter)
    case chapter(Chapter)
    case page(Int)
}

/// A container that contains the entire table of contents as a tree structure (i.e. the OutlineItem of the root) and as a list structure for ease of access and used to make certain operations easier.
///
/// Also handles depth limitation.
class OutlineContainer: Sequence {
    var root: OutlineItem
    var list: [OutlineItem] = []
    var depthLimitedList: [OutlineItem] = []
    var depthLimitation: Int
    
    init(root: OutlineItem, depthLimitation: Int = 2) {
        self.root = root
        self.depthLimitation = depthLimitation
        
        let list = Array(self)
        self.list = list
        self.depthLimitedList = list.filter({ $0.chapter.depth() <= depthLimitation })
    }
    
    // MARK: Sequence conformance
    
    func makeIterator() -> OutlineItemIterator {
        return OutlineItemIterator(root)
    }
    
    // MARK: Querying
     
    func getOutlineItem(_ query: QueryOption, depthLimited: Bool = false) -> OutlineItem? {
        let list = depthLimited ? depthLimitedList : list
        
        switch query
        {
        case .chapter(let chapter):
            return getOutlineItem(chapter: chapter, depthLimited: depthLimited)
        case .page(let page):
            return getOutlineItem(list: list, page: page)
        case .previousBefore(let chapter):
            return getOutlineItem(list: list, relativeTo: chapter, incrementedBy: -1)
        case .nextAfter(let chapter):
            return getOutlineItem(list: list, relativeTo: chapter, incrementedBy: 1)
        }
    }
    
    private func getOutlineItem(list: [OutlineItem], page: Int) -> OutlineItem {
        let outlineItemIndex = list.firstIndex(where: { item in
            item.page > page
        }) ?? list.endIndex
        
        return list[Swift.max(outlineItemIndex - 1, 0)]
    }
    
    private func getOutlineItem(chapter: Chapter, depthLimited: Bool) -> OutlineItem? {
        guard var index = list.firstIndex(where: { $0.chapter == chapter }) else {
            return nil
        }
        
        if depthLimited == false {
            return list[index]
        }
        
        while list[index].chapter.depth() > self.depthLimitation && index >= 0 {
            index -= 1
        }
        
        return list[index]
    }
    
    private func getOutlineItem(list: [OutlineItem], relativeTo chapter: Chapter, incrementedBy inc: Int) -> OutlineItem? {
        guard let outlineItem = list.first(where: { $0.chapter == chapter }) else {
            return nil
        }
        
        guard let currentIndex = list.firstIndex(of: outlineItem) else {
            return nil
        }
        
        let newIndex = currentIndex + inc
        
        if newIndex < 0 || newIndex >= list.count
        {
            return nil
        }
        
        return list[newIndex]
    }
    
    // MARK: Altering the table of contents (adding, deleting, moving, etc.)
    
    func addChild(_ item: OutlineItem) {
        // Get the page number and chapter to give the new child
        let pageNumber: Int
        let chapter: Chapter
        
        if item.children.count == 0
        {
            pageNumber = item.page
            chapter = Chapter(item.chapter.indexes + [0])
        }
        else
        {
            let lastChild = item.children.last!
            pageNumber = lastChild.page
            var chapterIndexes = lastChild.chapter.indexes
            chapterIndexes[chapterIndexes.endIndex - 1] += 1
            chapter = Chapter(chapterIndexes)
        }
        
        // Create realm object of the child
        let realmObject = OutlineItemDB(label: "New Chapter", page: pageNumber, chapter: chapter)
        
        // Create outline item
        let child = OutlineItem(realmObject: realmObject, children: [], parent: item)
        
        // Add as child
        item.children.append(child)
    }
    
    func addSiblingBelow(_ item: OutlineItem) {
        guard let parent = item.parent else {
            return
        }
        
        let page: Int
        if let lastChild = item.children.last
        {
            page = lastChild.page
        }
        else
        {
            page = item.page
        }
        
        let realmObject = OutlineItemDB(label: "New Chapter", page: page, chapter: item.chapter)
        let sibling = OutlineItem(realmObject: realmObject, children: [], parent: item)
        
        parent.children.insert(sibling, at: item.index + 1)
        
        parent.performCleanup()
    }
    
    func deleteItem(_ item: OutlineItem) {
        guard let parent = item.parent else {
            return
        }
        
        parent.children.remove(at: item.index)
        root.performCleanup()
    }
    
    func shiftLeft(_ item: OutlineItem) {
        guard let parent = item.parent,
              let grandParent = parent.parent
        else { return }
        
        let bringChildrenStartIndex = item.index + 1
        let bringChildrenEndIndex = parent.children.endIndex
//        let bringChildrenRange = bringChildrenStartIndex..<bringChildrenEndIndex
        let bringChildren = parent.children[bringChildrenStartIndex..<bringChildrenEndIndex]
        parent.children.removeSubrange(bringChildrenStartIndex - 1..<bringChildrenEndIndex)
        
        let parentIndex = parent.index
        item.children = Array(bringChildren)
        item.parent = grandParent
        grandParent.children.insert(item, at: parentIndex + 1)
        
        root.performCleanup()
    }
    
    func shiftRight(_ item: OutlineItem) {
        guard let parent = item.parent,
              let insertInto = parent.child(at: item.index - 1)
        else {
            return
        }
        
        parent.children.remove(at: item.index)
        insertInto.children.append(item)
        
        parent.performCleanup()
    }
    
}
