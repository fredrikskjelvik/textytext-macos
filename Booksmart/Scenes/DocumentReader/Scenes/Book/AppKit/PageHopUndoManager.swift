import Foundation

class PageHopUndoManager: UndoManager {
    let containerDelegate: PDFViewContainerDelegate
    
    init(_ containerDelegate: PDFViewContainerDelegate) {
        self.containerDelegate = containerDelegate
        
        super.init()
        
        levelsOfUndo = 5
        
        NotificationCenter.default.addObserver(self, selector: #selector(onUndoManagerCheckpoint), name: NSNotification.Name.NSUndoManagerCheckpoint, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onUndoManagerCheckpoint), name: NSNotification.Name.NSUndoManagerDidUndoChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onUndoManagerCheckpoint), name: NSNotification.Name.NSUndoManagerDidRedoChange, object: nil)
    }
    
    @objc func onUndoManagerCheckpoint() {
        containerDelegate.onPageChangeUndoManagerCheckpoint(canUndo: self.canUndo, canRedo: self.canRedo)
    }
}
