import Combine
import SwiftUI
import Cocoa
import Factory

/// SwiftUI view containing NSViewControllerRepresentable with the text view inside it.
struct TextViewContainer: NSViewControllerRepresentable {
    @EnvironmentObject var readerState: ReaderState
    
    var notesState: NotesState {
        readerState.notesState
    }
    
    func makeNSViewController(context: Context) -> TextViewController {
        let textViewController = TextViewController(coordinator: context.coordinator, textContainerInset: NSSize(width: 60.0, height: 30.0), isEditable: true, isScrollable: true)
        
		return textViewController
	}
    
    /// This runs any time one of the binding variables in this class changes, thereby updating the represented NSView
	func updateNSViewController(_ nsViewController: TextViewController, context: Context) {
        if context.coordinator.currentChapter == notesState.currentOutlineItem.chapter
        {
            return
        }
        
        nsViewController.reloadView()
        
        context.coordinator.currentChapter = notesState.currentOutlineItem.chapter
	}
    
    func makeCoordinator() -> NotesTextViewContainerCoordinator {
        return NotesTextViewContainerCoordinator(self)
    }
}

/// The coordinator for TextViewContainer. Sends info between SwiftUI and TextView. Conforms to TextViewContainerDelegate.
class NotesTextViewContainerCoordinator: NSObject, TextViewContainerDelegate {
    @Injected(Container.realm) private var realm
    
    let parent: TextViewContainer
    var currentChapter = Chapter([])
    
    init(_ parent: TextViewContainer) {
        self.parent = parent
    }
    
    private func getCurrentOutlineItem() -> OutlineItem {
        return parent.notesState.currentOutlineItem
    }
    
    func loadChapterContents() -> CodedTextViewContents? {
        guard let note = parent.readerState.document.note else {
            fatalError("Document does not have a Note database object. (Should not be possible).")
        }
        
        let outlineItem = getCurrentOutlineItem()
                    
        if let chapterNoteInfo = note.noteChapters.first(where: { $0.outlineItem == outlineItem.realmObject })
        {
            return chapterNoteInfo.contents
        }
        
        return nil
    }
    
    func saveChapterContents(contents: CodedTextViewContents) -> Bool {
        guard let note = parent.readerState.document.note else {
            fatalError("Document does not have a Note database object. (Should not be possible).")
        }
        
        let outlineItem = getCurrentOutlineItem()
                    
        if let chapterNoteInfo = note.noteChapters.first(where: { $0.outlineItem == outlineItem.realmObject })
        {
            let chapterNoteInfo = chapterNoteInfo.thaw()!
            
            try! realm.write {
                chapterNoteInfo.contents = contents
            }
            
            return true
        }
        
        return false
    }
    
    func goToPage(_ page: Int) {
        parent.readerState.goToPage(page)
    }
    
    func viewDidAppearWithProperties(height: CGFloat) {
        return
    }
}
