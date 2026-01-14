import Foundation

class OutlineItemIterator: IteratorProtocol {
    private var flatList: [OutlineItem] = []
    private var index: Int = 0
    
    init(_ outlineItem: OutlineItem) {
        flatList = createFlatList(root: outlineItem)
    }
    
    private func createFlatList(root: OutlineItem) -> [OutlineItem] {
        flatList = []
        createFlatListRecursion(root: root)
        
        return flatList
    }
    
    private func createFlatListRecursion(root: OutlineItem) {
        flatList.append(root)
        
        for child in root.children
        {
            createFlatListRecursion(root: child)
        }
        
        return
    }
    
    func next() -> OutlineItem? {
        if index >= flatList.count {
            return nil
        }
        
        let val = flatList[index]
        
        index += 1
        
        return val
    }
}
