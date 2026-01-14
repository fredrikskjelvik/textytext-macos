import SwiftUI

struct CreateFlashcardView: View {
    @EnvironmentObject var readerState: ReaderState
    @StateObject var vm: CreateFlashcardState
    
    var flashcardsState: FlashcardsState {
        readerState.flashcardsState
    }
    
    init(parent: FlashcardsState) {
        self._vm = StateObject(wrappedValue: CreateFlashcardState(parent: parent))
    }
    
    var body: some View {
        VStack {
            navigationBar
            textInput
            bottomMenu
        }
        .cornerRadius(12)
        .padding()
        .background(Color.Monochrome.RegularWhite)
    }
}

extension CreateFlashcardView {
    var navigationBar: some View {
        HStack(alignment: .center, spacing: 10) {
            CircularIconButton(icon: "chevron.left", iconSize: 18, size: 25, action: {
                vm.focusedField = vm.focusedField.prev()
            })
            
            Text(vm.focusedField.rawValue).font(.title3)
            
            CircularIconButton(icon: "chevron.right", iconSize: 18, size: 25, action: {
                vm.focusedField = vm.focusedField.next()
            })
        }
    }
}

extension CreateFlashcardView {
    // "Add page" values
    
    var bottomMenu: some View {
        HStack(spacing: 12) {
            let title = vm.inEditingMode() ? "Edit Flashcard" : "Create Flashcard"
            
            PlainButtonComponent(
                text: title,
                background: .blue,
                textColor: .white,
                action: vm.submit
            )
            .disabled(vm.isValidFlashcard() == false)
            
            PlainButtonComponent(
                text: "Cancel",
                background: .blue,
                textColor: .white,
                action: vm.cancel
            )
            
            MenuComponent(
                selector: flashcardsState.flashcardInput.outlineItem?.label,
                placeHolder: "Add Chapter",
                list: {
                    var list = vm.outlineItemsList.map { "\($0.getPrefix()): \($0.label)" }
                    list[0] = "Add Chapter"
                    
                    return list
                },
                onSelect: { index in
                    let selected = vm.outlineItemsList[index]
                    flashcardsState.flashcardInput.outlineItem = selected.realmObject
                }
            )
            .fixedSize()
            
            Button("Current chapter") {
                let bookChapter = readerState.bookState.currentOutlineItem.chapter
                
                guard let flashcardChapter = readerState.outlineContainer.getOutlineItem(.chapter(bookChapter), depthLimited: true) else {
                    return
                }
                
                flashcardsState.flashcardInput.outlineItem = flashcardChapter.realmObject
            }
            
            MenuComponent(
                selector: flashcardsState.flashcardInput.page != nil ? String(flashcardsState.flashcardInput.page!) : nil,
                placeHolder: "Add page",
                list: {
                    if let numPages = readerState.document.book?.pages
                    {
                        return ["Add page"] + Array(1...numPages).map(String.init)
                    }
                    
                    return ["Add page"]
                }, onSelect: { index in
                    if index == 0
                    {
                        flashcardsState.flashcardInput.page = nil
                    }
                    else
                    {
                        flashcardsState.flashcardInput.page = index
                    }
                }
            )
            .fixedSize()
            
            Button("Current Page") {
                let page = readerState.bookState.currentPage
                    
                flashcardsState.flashcardInput.page = page
            }
        }
        .font(.system(size: 13))
    }
}

extension CreateFlashcardView {
    var textInput: some View {
        VStack {
            switch vm.focusedField
            {
            case .question:
                FlashcardsTextViewContainer(content: $readerState.flashcardsState.flashcardInput.question, isEditable: true, isScrollable: true, idealHeight: .constant(nil))
            case .hint:
                FlashcardsTextViewContainer(content: $readerState.flashcardsState.flashcardInput.hint, isEditable: true, isScrollable: true, idealHeight: .constant(nil))
            case .answer:
                FlashcardsTextViewContainer(content: $readerState.flashcardsState.flashcardInput.answer, isEditable: true, isScrollable: true, idealHeight: .constant(nil))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(Animation.linear, value: vm.focusedField)
    }
}
