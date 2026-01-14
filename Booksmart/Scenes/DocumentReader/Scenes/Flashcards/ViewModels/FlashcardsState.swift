import Foundation
import RealmSwift
import Factory

final class FlashcardsState: ReaderSubState {
    @Injected(Container.realm) private var realm
    
    @Published var flashcards: RealmSwift.List<FlashcardDB>
    
    override init(parent: ReaderState) {
        self.flashcards = parent.document.flashcards
        
        super.init(parent: parent)
    }
    
    // MARK: Observing Realm
    
    var token: NotificationToken? = nil
    
    func setToken() {
        self.token = nil
//        self.token = flashcards.observe({ [unowned self] (changes) in
//            switch changes
//            {
//            case .update(flashcards, deletions: let deletions, insertions: let insertions, modifications: let modifications):
//                self.objectWillChange.send()
//                print("Flashcards Count: \(flashcards.count) \n Deletions: \(deletions) \n Insertions: \(insertions) \n Modifications: \(modifications)")
//            default:
//                break
//            }
//        })
    }
    
    // MARK: Tab
    
    @Published var selectedTab: FlashcardsViewTab = .create
    let tabs: [FlashcardsViewTab] = [.create, .browse, .study]
    
    func changeTab(to tab: FlashcardsViewTab) {
        selectedTab = tab
    }
    
    func deleteFlashcard(_ flashcard: FlashcardDB) {
        guard let flashcard = flashcard.thaw() else {
            fatalError("Failed to thaw")
        }
        
        try? realm.write {
            realm.delete(flashcard)
        }
    }
    
    // MARK: CREATE
    
    @Published var flashcardInput = FlashcardInput()
    
    func editFlashcard(_ flashcard: FlashcardDB) {
        flashcardInput = FlashcardInput.createFromFlashcardInstance(flashcard)
        changeTab(to: .create)
    }
    
    func addFlashcardInSameChapter(outlineItem: OutlineItem) {
        flashcardInput = FlashcardInput()
        flashcardInput.outlineItem = outlineItem.realmObject
        
        changeTab(to: .create)
    }
    
    // MARK: ???
    
    @Published var selectedFlashcardId: ObjectId = ObjectId.generate()
    
    /// The method used to go from a search result to a flashcard
    func goToFlashcard(outlineItem: OutlineItem, flashcard: FlashcardDB, flashcardField: FlashcardField) {
        setOutlineItem(outlineItem)
        
        if selectedTab == .browse
        {
            selectedFlashcardId = flashcard.id
        }
        else
        {
            selectedTab = .browse
            selectedFlashcardId = ObjectId.generate()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                self.selectedFlashcardId = flashcard.id
            })
        }
    }
    
}
