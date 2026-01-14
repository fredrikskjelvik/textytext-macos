import Foundation
import PDFKit
import RealmSwift
import Combine

/// The main class for holding state in the document reader view. Contains properties for subcomponents' states (bookState, notesState, flashcardsState) and handles communication between them.
final class ReaderState: ObservableObject {
    init(document: DocumentDB) {
        self.document = document
        self.outlineContainer = document.getOutlineItemsContainer()
        
        self.bookState = BookState(parent: self)
        self.notesState = NotesState(parent: self)
        self.flashcardsState = FlashcardsState(parent: self)
        
        self.bookState?.objectWillChange.sink { [weak self ] (_) in
            self?.objectWillChange.send()
        }.store(in: &cancellable)
        
        self.notesState?.objectWillChange.sink { [weak self ] (_) in
            self?.objectWillChange.send()
        }.store(in: &cancellable)
        
        self.flashcardsState?.objectWillChange.sink { [weak self ] (_) in
            self?.objectWillChange.send()
        }.store(in: &cancellable)
    }
    
    var cancellable = Set<AnyCancellable>()
    
    var outlineContainer: OutlineContainer
    @Published var document: DocumentDB
    @Published var subsceneLayout: SubsceneLayoutManager = SubsceneLayoutManager(showing: [.book])
    
    // MARK: Access to substates
    
    @Published var bookState: BookState!
    @Published var notesState: NotesState!
    @Published var flashcardsState: FlashcardsState!
    
    // MARK: ??
    
    func setChapterInSubState<T: ReaderSubState>(_ type: T.Type, outlineItem: OutlineItem) {
        if type == BookState.self
        {
            subsceneLayout.unhide(.book)
            bookState?.setPage(outlineItem.page)
        }
        else if type == NotesState.self
        {
            subsceneLayout.unhide(.notes)
            notesState?.setOutlineItem(outlineItem)
        }
        else if type == FlashcardsState.self
        {
            subsceneLayout.unhide(.flashcards)
            flashcardsState?.setOutlineItem(outlineItem)
        }
    }
    
    // MARK: Events from BookState that need to be completed here
    
    func createFlashcardFromSelection(selection: String) {
        // RETVRN
        subsceneLayout.unhide(.flashcards)

        guard let bookState = bookState else { return }
        guard let flashcardsState = flashcardsState else { return }
        
        // Convert book chapter to depth limited flashcard chapter
        let bookChapter = bookState.currentOutlineItem.chapter
        
        guard let flashcardChapter = outlineContainer.getOutlineItem(.chapter(bookChapter), depthLimited: true) else {
            return
        }
        
        // Set input values of flashcard
        var input = FlashcardInput()
            input.answer = CodedTextViewContents(string: selection)
            input.outlineItem = flashcardChapter.realmObject
            input.page = bookState.currentPage

        flashcardsState.flashcardInput = input
        flashcardsState.changeTab(to: .create)
    }
    
    // MARK: Ad hoc
    
    // TODO: Make a good way to do cross-subview view changes. Something with the two methods below and `setChapterInSubState`
    
    /// This method is ad hoc. Will probably remove it.
    /// - Parameter page: page index
    func goToPage(_ page: Int) {
        bookState?.currentPage = page
    }
    
    /// The method used to go from a search result to a flashcard
    func goToFlashcard(outlineItem: OutlineItem, flashcard: FlashcardDB, flashcardField: FlashcardField) {
        subsceneLayout.unhide(.flashcards)
        flashcardsState?.goToFlashcard(outlineItem: outlineItem, flashcard: flashcard, flashcardField: flashcardField)
    }
}

class ReaderSubState: ObservableObject {
    var parent: ReaderState
    @Published var currentOutlineItem: OutlineItem
    
    init(parent: ReaderState) {
        self.parent = parent
        self.currentOutlineItem = OutlineContainerFactory.copyRoot(outline: parent.outlineContainer)
    }
    
    func setChapterInSubState<T: ReaderSubState>(_ type: T.Type, outlineItem: OutlineItem) {
        parent.setChapterInSubState(type, outlineItem: outlineItem)
    }
    
    func setOutlineItem(_ item: OutlineItem) {
        currentOutlineItem = item
    }
}
