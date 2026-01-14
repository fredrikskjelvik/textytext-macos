import SwiftUI
import PDFKit

struct Reader: View {
    var body: some View {
        NavigationView {
            NavigationSidebar()
            
            FlexiGrid(bookViewBuilder: {
                BookContainer()
            }, notesViewBuilder: {
                NotesContainer()
            }, flashcardsViewBuilder: {
                FlashcardsView()
            })
            .frame(
                minWidth: 900,
//                idealWidth: 1200,
                maxWidth: .infinity,
                minHeight: 700,
//                idealHeight: 1000,
                maxHeight: .infinity,
                alignment: .center
            )
        }
        .readerToolbar()
        .blurEffect()
    }
}
