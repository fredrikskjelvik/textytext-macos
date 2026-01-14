import Foundation
import RealmSwift

struct FlashcardInput {
    var id: ObjectId? = nil
    var question: CodedTextViewContents? = nil
    var answer: CodedTextViewContents? = nil
    var hint: CodedTextViewContents? = nil
    var page: Int? = nil
    var outlineItem: OutlineItemDB? = nil
    var tags: [String] = []
    
    static func createFromFlashcardInstance(_ flashcard: FlashcardDB) -> FlashcardInput {
        return FlashcardInput(
            id: flashcard.id,
            question: flashcard.question,
            answer: flashcard.answer,
            hint: flashcard.hint,
            page: flashcard.page,
            outlineItem: flashcard.outlineItem,
            tags: Array(flashcard.tags)
        )
    }
    
    // This flashcard is valid, as in, it is complete enough to be added. I.e. it can't have an empty question field.
    func isValid() -> Bool {
        return true
    }
    
}
