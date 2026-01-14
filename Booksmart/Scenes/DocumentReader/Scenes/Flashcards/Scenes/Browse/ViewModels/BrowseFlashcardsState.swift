import Combine
import RealmSwift
import Foundation
import Factory

class BrowseFlashcardsState: ObservableObject {
    @Injected(Container.realm) private var realm
    
    var parent: FlashcardsState
    @Published var listItems: [GenericBrowseFlashcardsListItem] = []
    
    init(parent: FlashcardsState) {
        self.parent = parent
        self.listItems = initializeListItems()
    }
    
    // MARK: Initialize list items
    private func initializeListItems() -> [GenericBrowseFlashcardsListItem] {
        var listItems: [GenericBrowseFlashcardsListItem] = []
        
        let document = parent.parent.document
        let outlineItemsList = parent.parent.outlineContainer.depthLimitedList
        
        for item in outlineItemsList {
            listItems.append(createTitle(outlineItem: item))
            
            let flashcards = document.flashcards.where({ obj in
                obj.outlineItem.id == item.realmObject.id
            })
            
            for flashcard in flashcards
            {
                listItems.append(createFlashcard(outlineItem: item, flashcard: flashcard))
            }
        }
        
        return listItems
    }
    
    private func createTitle(outlineItem: OutlineItem) -> BrowseFlashcardsListItemTitle {
        return BrowseFlashcardsListItemTitle(outlineItem: outlineItem)
    }
    
    private func createFlashcard(outlineItem: OutlineItem, flashcard: FlashcardDB) -> BrowseFlashcardsListItemFlashcard {
        return BrowseFlashcardsListItemFlashcard(
            id: flashcard.id,
            outlineItem: outlineItem,
            flashcard: flashcard
        )
    }
    
    // MARK: Move list items
    func move(from source: IndexSet, to destination: Int) {
        assert(source.count == 1) // Do not handle multi select currently
        
        var destination = destination
        let sourceIndex = source.first!
        
        var updatedListItems = listItems
            updatedListItems.move(fromOffsets: source, toOffset: destination)
        
        // Adjust destination - if destination is greater than source index, we are moving in a downward direction
        // if that is the case, then we have to shift destination to account for the fact that the removed value was
        // removed to the left (in the array) of the new destination, thereby affecting the index. if it is removed
        // on the right side of destination in the array, the index is not affected.
        destination -= sourceIndex < destination ? 1 : 0
        
        guard var movedFlashcard = updatedListItems[destination] as? BrowseFlashcardsListItemFlashcard else {
            return
        }
        
        // Go to the first title above the destination
        for i in stride(from: destination - 1, through: 0, by: -1)
        {
            if let titleItem = updatedListItems[i] as? BrowseFlashcardsListItemTitle
            {
                let flashcard = movedFlashcard.flashcard.thaw()!
                let newOutlineItem = titleItem.outlineItem
                
                try! realm.write {
                    flashcard.outlineItem = newOutlineItem.realmObject
                }
                
                movedFlashcard.outlineItem = newOutlineItem
                updatedListItems[destination] = movedFlashcard
                
                break
            }
        }
        
        listItems = updatedListItems
    }
    
}
