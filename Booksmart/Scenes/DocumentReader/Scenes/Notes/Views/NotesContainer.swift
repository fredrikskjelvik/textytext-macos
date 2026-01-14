import SwiftUI

/// The container for the entire "Notes" subcomponent/subscene thing.
/// Contains the toolbar and the TextView.
struct NotesContainer: View {
    @EnvironmentObject var readerState: ReaderState
    
    var notesState: NotesState {
        readerState.notesState
    }
    
    var body: some View {
        VStack {
            HStack {
                Button("<") {
                    notesState.goToPrevChapter()
                }
                .disabled(notesState.isFirstChapter())
                .keyboardShortcut(.leftArrow, modifiers: .command)
                
                ChapterSelectorMenuView(
                    chapters: readerState.outlineContainer.depthLimitedList,
                    current: $readerState.notesState.currentOutlineItem
                )
                
                Button(">") {
                    notesState.goToNextChapter()
                }
                .disabled(notesState.isLastChapter())
                .keyboardShortcut(.rightArrow, modifiers: .command)
            }
            .frame(maxWidth: .infinity)
            
            TextViewContainer()
        }
    }
}

//struct NotesContainer_Previews: PreviewProvider {
//    static var previews: some View {
//        NotesContainer()
//    }
//}
