import SwiftUI

class StudyFlashcardState: ObservableObject {
    var parent: FlashcardsState
    var flashcards: [FlashcardDB]
    
    @Published var focusedField: FlashcardField = .question
    @Published var currentFlashcard: FlashcardDB!
    
    init(parent: FlashcardsState) {
        self.parent = parent
        self.flashcards = Array(parent.flashcards)
        setNextFlashcard()
    }
    
    func setNextFlashcard() {
        currentFlashcard = flashcards.randomElement()!
    }
    
    func goToPage() {
        if let page = currentFlashcard.page {
            // TODO: Figure out what the hell is going on, but for now just do -1
            parent.parent.bookState.setPage(page)
        }
    }
    
    func goToChapter() {
        guard let flashcardChapter = currentFlashcard.outlineItem?.chapter else { return }
        
        if let outlineItem = parent.parent.outlineContainer.getOutlineItem(.chapter(flashcardChapter))
        {
            parent.setChapterInSubState(BookState.self, outlineItem: outlineItem)
        }
    }
    
    func goToFlashcardEditingView() {
        parent.editFlashcard(currentFlashcard)
    }
    
}
