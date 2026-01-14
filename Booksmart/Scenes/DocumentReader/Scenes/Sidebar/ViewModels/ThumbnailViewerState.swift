import Foundation
import RealmSwift

enum PickerSelection: String {
    case allPages
    case bookmarks
}

class ThumbnailViewerState: ObservableObject {
    var book: BookDB
    
    init(parent: BookState) {
        self.book = parent.book
        
        guard let pageManager = parent.pdfView?._pages else { return }
        
        self.allPages = pageManager.allPages.map({ $0.getModel() })
        self.displayedPages = allPages
    }
    
    @Published var pickerSelection = PickerSelection.allPages {
        didSet {
            switch pickerSelection
            {
            case .allPages:
                self.displayedPages = allPages
            case .bookmarks:
                let bookmarks = Array(book.bookmarks)
                self.displayedPages = allPages.filter({
                    bookmarks.contains($0.pageNumber)
                })
            }
        }
    }
    
    @Published var displayedPages = [PageModel]()
    
    var allPages = [PageModel]()
}
