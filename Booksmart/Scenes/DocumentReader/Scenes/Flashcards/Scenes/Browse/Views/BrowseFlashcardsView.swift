import SwiftUI
import RealmSwift

struct BrowseFlashcardsView: View {
    @EnvironmentObject var readerState: ReaderState
    var flashcardsState: FlashcardsState {
        readerState.flashcardsState
    }
    
    @StateObject var vm: BrowseFlashcardsState
    
    init(parent: FlashcardsState) {
        self._vm = StateObject(wrappedValue: BrowseFlashcardsState(parent: parent))
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            SwiftUI.List {
                ForEach(vm.listItems, id: \.id) { item in
                    if let header = item as? BrowseFlashcardsListItemTitle
                    {
                        BrowseFlashcardsChapterHeader(name: header.name, size: header.size)
                            .padding(.top, BrowseFlashcardsListItemTitle.space)
                            .tag(item.id)
                    }
                    else if let flashcardItem = item as? BrowseFlashcardsListItemFlashcard
                    {
                        FlashcardComponent(
                            flashcard: flashcardItem.flashcard,
                            isSelected: flashcardsState.selectedFlashcardId == flashcardItem.id,
                            onTap: {
                                flashcardsState.selectedFlashcardId = flashcardItem.id
                            },
                            onClickAdd: {
                                flashcardsState.addFlashcardInSameChapter(outlineItem: item.outlineItem)
                            },
                            onClickEdit: {
                                flashcardsState.editFlashcard(flashcardItem.flashcard)
                            },
                            onClickDelete: {
                                vm.listItems.removeAll(where: { $0.id == item.id })
                                flashcardsState.deleteFlashcard(flashcardItem.flashcard)
                            })
                        .padding(.top, BrowseFlashcardsListItemFlashcard.space)
                        .tag(item.id)
                    }
                }
                .onMove(perform: vm.move)
                
                Text("")
                    .onChange(of: flashcardsState.selectedFlashcardId) { id in
                        proxy.scrollTo(id, anchor: UnitPoint.top)
                    }
            }
        }
    }
}

struct FlashcardComponent: View {
    @State var flashcard: FlashcardDB
    var isSelected: Bool
    
    var onTap: () -> Void
    var onClickAdd: () -> Void
    var onClickEdit: () -> Void
    var onClickDelete: () -> Void
    
    var frameHeight: Double {
        guard let idealHeight = idealHeight else {
            return minHeight
        }
        
        if isSelected
        {
            return idealHeight
        }
        else
        {
            if idealHeight < minHeight
            {
                return idealHeight
            }
            
            return minHeight
        }
    }
    
    let minHeight: CGFloat = 148 + 25 + 15 // Height + Inner Padding + Outertop Padding
    @State var idealHeight: Double? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Leading menu icons
            ZStack(alignment: .topLeading) {
                // Disable drag on invisible area
                VStack {
                    Spacer()
                }
                .frame(width: 16)
                .contentShape(Rectangle())
                .onTapGesture {}
                
                // Options
                VStack(spacing: 10) {
                    FlashcardOption(image: Image(systemName: "square.grid.3x3.fill"))
                    FlashcardOptionButton(image: Image(systemName: "plus"), action: onClickAdd)
                    FlashcardOptionButton(image: Image(systemName: "square.and.pencil"), action: onClickEdit)
                    FlashcardOptionButton(image: Image(systemName: "trash"), action: onClickDelete)
                }
                .padding(.top, 22)
                .opacity(isSelected ? 1 : 0)
                .disabled(!isSelected)
            }
            
            ZStack {
                if isSelected {
                    Color.blue
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        FlashcardsTextViewContainer(content: $flashcard.question, isEditable: false, isScrollable: false, idealHeight: $idealHeight)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.linear, value: isSelected)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(10)
                .padding(2)
            }
            .cornerRadius(10)
            .shadow(color: Color.Monochrome.Gray, radius: 2, x: 0, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture(perform: onTap)
        }
        .frame(height: frameHeight)
    }
}


struct FlashcardOption: View {
    let image: Image
    var body: some View {
        image
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .frame(width: 16, height: 16)
    }
}

struct FlashcardOptionButton: View {
    let image: Image
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            FlashcardOption(image: image)
        }
        .buttonStyle(.plain)
    }
}



// implement Hashable?
protocol GenericBrowseFlashcardsListItem {
    var id: ObjectId { get set }
    var outlineItem: OutlineItem { get set }
    static var space: Double { get set }
}

struct BrowseFlashcardsListItemTitle: GenericBrowseFlashcardsListItem {
    var id = ObjectId.generate()
    var outlineItem: OutlineItem
    static var space = 58.0
    
    var name: String {
        outlineItem.label
    }
    
    var size: Font {
        let depth = outlineItem.chapter.depth()
        if depth < 2
        {
            return .system(size: 36)
        }
        else
        {
            return .system(size: 24)
        }
    }
}

struct BrowseFlashcardsListItemFlashcard: GenericBrowseFlashcardsListItem {
    var id: ObjectId
    var outlineItem: OutlineItem
    static var space = 15.0
    
    var flashcard: FlashcardDB
}
