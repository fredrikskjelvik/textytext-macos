import Foundation

enum FlashcardField: String, Hashable {
    case question = "Question"
    case hint = "Hint"
    case answer = "Answer"
    
    func next() -> FlashcardField {
        switch self
        {
        case .question:
            return .hint
        case .hint:
            return .answer
        case .answer:
            return .question
        }
    }
    
    func prev() -> FlashcardField {
        switch self
        {
        case .question:
            return .answer
        case .hint:
            return .question
        case .answer:
            return .hint
        }
    }
}
