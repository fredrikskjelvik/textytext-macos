import SwiftUI
import PDFKit

/// The view with the table of contents in the sidebar
struct BookOutlineView: View {
    @EnvironmentObject var readerState: ReaderState
    
    var notesState: NotesState {
        readerState.notesState
    }
    
    var bookState: BookState {
        readerState.bookState
    }
    
    var body: some View {
        let chapterLevelOutlineItems = readerState.outlineContainer.root.children
        
        List {
            OutlineGroup(chapterLevelOutlineItems, children: \._children) { item in
                OutlineItemButton(outlineItem: item)
            }
        }
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    func OutlineItemButton(outlineItem: OutlineItem) -> some View {
        Button(action: {
            bookState.setPage(outlineItem.page)
        }, label: {
            HStack {
                Text(outlineItem.label)
                
                Spacer()
                
                Text(String(outlineItem.page))
            }
        })
        .buttonStyle(.plain)
        .tag(outlineItem.id)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundColor(isActiveOutlineItem(outlineItem) ? Color.white : Color.black)
        .background(isActiveOutlineItem(outlineItem) ? Color.Primary.Regular : Color.clear)
        .cornerRadius(7)
    }
    
    private func isActiveOutlineItem(_ item: OutlineItem) -> Bool {
        return item == bookState.currentOutlineItem
    }
}

struct BookOutline_Previews: PreviewProvider {
    static var previews: some View {
        BookOutlineView()
    }
}
