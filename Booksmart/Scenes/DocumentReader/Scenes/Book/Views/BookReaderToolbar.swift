import SwiftUI

struct BookReaderToolbarView: View {
    @EnvironmentObject var readerState: ReaderState
    
    var bookState: BookState {
        readerState.bookState
    }
    
    var canUndo: Bool
    var canRedo: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name.DidRequestUndoPageHop, object: nil)
            }, label: {
                Image(systemName: "chevron.left")
            })
            .buttonStyle(PlainButtonStyle())
            .disabled(!canUndo)
            
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name.DidRequestRedoPageHop, object: nil)
            }, label: {
                Image(systemName: "chevron.right")
            })
            .buttonStyle(PlainButtonStyle())
            .disabled(!canRedo)
            
            Divider()
            
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name.DidRequestZoomOut, object: nil)
            }, label: {
                Image(systemName: "minus.magnifyingglass")
            })
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name.DidRequestZoomIn, object: nil)
            }, label: {
                Image(systemName: "plus.magnifyingglass")
            })
            .buttonStyle(PlainButtonStyle())
            
            Divider()
            
            Image(systemName: "pencil.tip")
            
            Spacer()
            
            Button(action: {
                bookState.toggleBookmarkAtCurrentPage()
            }, label: {
                Image(systemName: bookState.currentPageHasBookmark() ? "bookmark.fill" : "bookmark")
            })
            .buttonStyle(PlainButtonStyle())
        }
        .font(.system(size: 18))
        .foregroundColor(Color.Monochrome.Gray)
        .frame(maxWidth: .infinity, maxHeight: 26)
        .padding()
    }
}
