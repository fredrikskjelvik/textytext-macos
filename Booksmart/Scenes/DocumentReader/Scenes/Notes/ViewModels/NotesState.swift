import Foundation
import SwiftUI
import Combine
import PDFKit
import RealmSwift

final class NotesState: ReaderSubState {
    @Published var note: NoteDB?
    
    override init(parent: ReaderState) {
        self.note = parent.document.note
        
        super.init(parent: parent)
        
        setToken()
    }
    
    // MARK: Observing Realm
    
    var token: NotificationToken? = nil
    
    func setToken() {
        token = note?.observe({ [unowned self] (changes) in
            switch changes {
                case .error(_):
                    break
                case .change(_, _):
                    self.objectWillChange.send()
                case .deleted:
                    self.note = nil
            }
        })
    }
    
    @Published var selectedText: String = ""
    
    func goToPrevChapter() {
        let container = parent.outlineContainer
        
        if let newOutlineItem = container.getOutlineItem(.previousBefore(currentOutlineItem.chapter), depthLimited: true) {
            currentOutlineItem = newOutlineItem
        }
    }
    
    func goToNextChapter() {
        let container = parent.outlineContainer
        
        if let newOutlineItem = container.getOutlineItem(.nextAfter(currentOutlineItem.chapter), depthLimited: true) {
            currentOutlineItem = newOutlineItem
        }
    }
    
    func isFirstChapter() -> Bool {
        return currentOutlineItem.chapter.isRoot()
    }
    
    func isLastChapter() -> Bool {
        let container = self.parent.outlineContainer
        
        return container.getOutlineItem(.nextAfter(currentOutlineItem.chapter)) == nil
    }
}
