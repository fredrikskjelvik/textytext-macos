import Combine
import RealmSwift
import Foundation
import Factory

class CreateFlashcardState: ObservableObject {
    @Injected(Container.realm) private var realm
    
    var parent: FlashcardsState
    
    init(parent: FlashcardsState) {
        self.parent = parent
    }
    
    @Published var focusedField: FlashcardField = .question
    
    func cancel() {
        parent.flashcardInput = FlashcardInput()
        parent.changeTab(to: .browse)
    }
    
    func submit() {
        let input = parent.flashcardInput
        let document = parent.parent.document
        let outlineContainer = parent.parent.outlineContainer
        let builder = FlashcardBuilder()
        let isUpdating = input.id != nil
        
        if input.isValid() == false {
            return
        }
        
        if let id = input.id {
            builder.addId(id)
        }
        
        if let question = input.question,
           let answer = input.answer {
            builder.addQA(question: question, answer: answer)
        }
        
        if let hint = input.hint {
            builder.addHint(hint)
        }
        
        if let outlineItem = input.outlineItem
        {
            builder.addOutlineItem(outlineItem)
        }
        else
        {
            let root = outlineContainer.root.realmObject
            builder.addOutlineItem(root)
        }
        
        if let page = input.page {
            builder.addPage(page)
        }
        
        builder.addTags(input.tags)
        
        let flashcard = builder.getProduct()
                
        try! realm.write {
            if isUpdating
            {
                guard let flashcardToOverwrite = document.flashcards.first(where: { $0.id == flashcard.id }) else {
                    return
                }
                
                realm.delete(flashcardToOverwrite)
            }
            
            document.flashcards.append(flashcard)
        }
        
        cancel()
    }
    
    func inEditingMode() -> Bool {
        return parent.flashcardInput.id != nil
    }
    
    func isValidFlashcard() -> Bool {
        return parent.flashcardInput.isValid()
    }
    
    var outlineItemsList: [OutlineItem] {
        parent.parent.outlineContainer.depthLimitedList
    }
    
}
