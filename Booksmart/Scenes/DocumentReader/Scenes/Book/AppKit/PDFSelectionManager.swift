import PDFKit

class PDFSelectionManager {
    let selection: PDFSelection
    let _document: PDFDocumentManager
    let _pages: PDFPagesManager
    
    init(_ selection: PDFSelection, document: PDFDocumentManager, pages: PDFPagesManager) {
        self.selection = selection
        self._document = document
        self._pages = pages
    }
    
    // MARK: Direct copy
    
    var pages: [PDFPageManager] {
        return _pages.convert(pages: selection.pages)
    }
    
    func bounds(for page: PDFPageManager) -> CGRect {
        return selection.bounds(for: page.page)
    }
    
    func selectionsByLine() -> [PDFSelectionManager] {
        return selection.selectionsByLine().map({ (selection) in
            return PDFSelectionManager(selection, document: _document, pages: _pages)
        })
    }
    
}
