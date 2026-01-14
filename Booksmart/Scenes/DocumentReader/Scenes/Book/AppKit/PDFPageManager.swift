import PDFKit

class PDFPagesManager {
    let document: PDFDocumentManager
    init(_ document: PDFDocumentManager) {
        self.document = document
        
        for pageIndex in 0..<document.document.pageCount
        {
            allPages.append(PDFPageManager(page: document.page(at: pageIndex)!, pageNumber: pageIndex))
        }
    }
    
    // MARK: Pages
    
    var allPages: [PDFPageManager] = []
    
    subscript(_ index: Int) -> PDFPageManager? {
        return allPages[safe: index]
    }
    
    // MARK: Direct copy
    
    var pageCount: Int {
        return allPages.count
    }
    
    // MARK: Other
    
    func convert(pages: [PDFPage]) -> [PDFPageManager] {
        return pages.map({ convert(page: $0) })
    }
    
    func convert(page: PDFPage) -> PDFPageManager {
        return allPages.first(where: { $0.page == page })!
    }
    
}

class PDFPageManager: Comparable {
    let page: PDFPage
    let pageNumber: Int
    
    init(page: PDFPage, pageNumber: Int) {
        self.page = page
        self.pageNumber = pageNumber
    }
    
    // MARK: Direct Copy
    
    func removeAnnotation(_ annotation: PDFAnnotation) {
        page.removeAnnotation(annotation)
    }
    
    // MARK: Highlights
    
    var highlights: [PDFAnnotation] {
        return page.getAnnotations(of: PDFAnnotationSubtype.highlight)
    }
    
    var legitHighlights: [PDFHighlightAnnotation] {
        return page
            .getAnnotations(of: PDFAnnotationSubtype.highlight)
            .map({ highlight in
                highlight.toHighlight()!
            })
    }
    
    func addHighlight(bounds: CGRect, color: NSColor = NSColor.systemYellow) {
        let highlight = PDFHighlightAnnotation(bounds: bounds, color: color, page: page)
        
        page.addAnnotation(highlight)
        page.displaysAnnotations = true
    }
    
    // MARK: Comparable
    
    static func == (lhs: PDFPageManager, rhs: PDFPageManager) -> Bool {
        return lhs.pageNumber == rhs.pageNumber
    }
    
    static func < (lhs: PDFPageManager, rhs: PDFPageManager) -> Bool {
        return lhs.pageNumber < rhs.pageNumber
    }
    
    // MARK: Model
    
    func getModel() -> PageModel {
        return PageModel(page: page, pageNumber: pageNumber)
    }
    
}

struct PageModel: Hashable, Identifiable {
    let id = UUID()
    let page: PDFPage
    let pageNumber: Int
    
    func getThumbnail(size: NSSize) -> NSImage {
        return page.thumbnail(of: size, for: .mediaBox)
    }
}
