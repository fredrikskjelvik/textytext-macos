import Foundation
import SwiftUI
import Combine
import PDFKit
import RealmSwift
import Factory

final class BookState: ReaderSubState {
    @Injected(Container.realm) private var realm
    
    @Published var book: BookDB
    
    override init(parent: ReaderState) {
        self.book = parent.document.book!
        
        super.init(parent: parent)
        
        setToken()
    }
    
    // MARK: Observing Realm
    var token: NotificationToken? = nil
    
    func setToken() {
        token = book.observe({ [unowned self] (changes) in
            switch changes
            {
            case .change(_, _):
                self.objectWillChange.send()
            default:
                break
            }
        })
    }
    
    // MARK: PDF View and Status
    var pdfView: CustomPDFView?
    
    @Published var currentPage: Int = 0
    
    // MARK: Bookmarks
    func currentPageHasBookmark() -> Bool {
        return book.hasBookmark(at: currentPage)
    }
    
    func toggleBookmarkAtCurrentPage() {
        guard let book = self.book.thaw() else { return }
        let page = currentPage
        
        try? realm.write {
            if let index = book.bookmarks.firstIndex(of: page)
            {
                book.bookmarks.remove(at: index)
            }
            else
            {
                book.bookmarks.append(page)
            }
        }
    }
    
    // MARK: ??
    
    func setPage(_ page: Int) {
        currentPage = page
        
        let outlineContainer = self.parent.outlineContainer
        guard let outlineItemAtPage = outlineContainer.getOutlineItem(.page(currentPage)) else {
            return
        }
        
        currentOutlineItem = outlineItemAtPage
    }
    
    override func setOutlineItem(_ item: OutlineItem) {
        setPage(item.page)
    }
}
