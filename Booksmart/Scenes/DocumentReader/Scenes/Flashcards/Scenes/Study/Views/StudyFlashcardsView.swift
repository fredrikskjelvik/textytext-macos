import SwiftUI

struct StudyFlashcardsView: View {
    @EnvironmentObject var readerState: ReaderState
    
    var flashcardsState: FlashcardsState {
        readerState.flashcardsState
    }
    
    @StateObject var vm: StudyFlashcardState
    
    init(parent: FlashcardsState) {
        self._vm = StateObject(wrappedValue: StudyFlashcardState(parent: parent))
    }
    
    var body: some View {
        VStack(alignment: .center) {
            navigationBar
            flashcardField
            bottomMenu
        }
        .background(Color.Monochrome.RegularWhite)
        .cornerRadius(15)
    }
}

extension StudyFlashcardsView {
    var navigationBar: some View {
        HStack(alignment: .center, spacing: 15) {
            CircularIconButton(icon: "chevron.left", iconSize: 18, size: 25, action: {
                vm.focusedField = vm.focusedField.prev()
            })
            
            Text(vm.focusedField.rawValue).font(.title3)
            
            CircularIconButton(icon: "chevron.right", iconSize: 18, size: 25, action: {
                vm.focusedField = vm.focusedField.next()
            })
        }
        .padding()
    }
}

extension StudyFlashcardsView {
    var flashcardField: some View {
        Group {
            switch vm.focusedField
            {
            case .question:
                FlashcardsTextViewContainer(content: $vm.currentFlashcard.question, isEditable: false, isScrollable: true, idealHeight: .constant(0.0))
            case .hint:
                FlashcardsTextViewContainer(content: $vm.currentFlashcard.hint, isEditable: false, isScrollable: true, idealHeight: .constant(0.0))
            case .answer:
                FlashcardsTextViewContainer(content: $vm.currentFlashcard.answer, isEditable: false, isScrollable: true, idealHeight: .constant(0.0))
            }
        }
        .frame(width: .infinity, height: .infinity, alignment: .center)
    }
}

extension StudyFlashcardsView {
    var bottomMenu: some View {
        HStack {
            PlainButtonComponent(
                text: vm.focusedField == .answer ? "Hide answer" : "Show answer",
                background: Color.blue,
                textColor: Color.white,
                action: {
                    if vm.focusedField == .answer
                    {
                        vm.focusedField = .question
                    }
                    else if vm.focusedField == .question
                    {
                        vm.focusedField = .answer
                    }
                }
            )
            
            if vm.focusedField == .answer
            {
                VStack {
                    HStack{
                        PlainButtonComponent(text: "Again", action: {
                            vm.focusedField = .question
                            vm.setNextFlashcard()
                        })
                        PlainButtonComponent(text: "Hard", action: {
                            vm.focusedField = .question
                            vm.setNextFlashcard()
                        })
                        PlainButtonComponent(text: "Good", action: {
                            vm.focusedField = .question
                            vm.setNextFlashcard()
                        })
                        PlainButtonComponent(text: "Easy", action: {
                            vm.focusedField = .question
                            vm.setNextFlashcard()
                        })
                    }
                    .padding(.bottom, 10)
    
                    HStack {
                        if vm.currentFlashcard.page != nil {
                            Button("Go to page", action: vm.goToPage)
                        }
    
                        if vm.currentFlashcard.outlineItem != nil {
                            Button("Go to chapter", action: vm.goToChapter)
                        }
    
                        Button("Edit Flashcard", action: vm.goToFlashcardEditingView)
                    }
                }
            }
        }
        .padding()
    }
}

//struct StudyFlashcardsView_Previews: PreviewProvider {
//    static var readerState: ReaderState {
//        let realm = RealmManager.standard.realm
//        let document = realm.objects(DocumentDB.self).first!
//
//        return ReaderState(document: document)
//    }
//
//    static var flashcardsState: FlashcardsState {
//        return FlashcardsState(parent: readerState)
//    }
//
//    static var previews: some View {
//        StudyFlashcardsView(parent: flashcardsState)
//    }
//}
