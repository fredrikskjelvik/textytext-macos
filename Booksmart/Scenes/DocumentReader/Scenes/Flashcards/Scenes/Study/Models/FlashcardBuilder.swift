import Foundation
import RealmSwift

class FlashcardBuilder {
    private var product = FlashcardDB()
    
    func addId(_ id: ObjectId) {
        product.id = id
    }
    
    func addQA(question: CodedTextViewContents, answer: CodedTextViewContents) {
        product.question = question
        product.answer = answer
    }
    
    func addHint(_ hint: CodedTextViewContents) {
        product.hint = hint
    }
    
    func addOutlineItem(_ outlineItem: OutlineItemDB) {
        product.outlineItem = outlineItem
    }
    
    func addPage(_ page: Int) {
        product.page = page
    }
    
    func addTags(_ tags: [String]) {
        for tag in tags {
            product.tags.append(tag)
        }
    }
    
    func getProduct() -> FlashcardDB {
        return product
    }
}
