import Foundation

/// This struct encapsulates chapter, subchapter, sub-subchapter etc. in an array,
///
/// Example:
/// -  [1, 0] = Chapter 2.1
/// - [2] = Chapter 3
struct Chapter {
    init(_ indexes: [Int]) {
        self.indexes = indexes
    }
    
    var indexes: [Int] = []
    
    var chapter: Int? {
        indexes[safe: 0]
    }
    
    var subchapter: Int? {
        indexes[safe: 1]
    }
    
    /// Chapter depth = 1, subchapter depth = 2, etc...
    func depth() -> Int {
        return indexes.count
    }
    
    /// Get the readable representation of a chapter for the UI
    func getPrefix() -> String {
        if isRoot() {
            return "0"
        }
        
        return indexes
                .map({ $0 + 1 })
                .map(String.init)
                .joined(separator: ".")// + ")"
    }
    
    /// Returns true if this chapter is root
    func isRoot() -> Bool {
        return indexes.isEmpty
    }
}
