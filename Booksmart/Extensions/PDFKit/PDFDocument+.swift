import PDFKit

extension PDFDocument {
    
    // MARK: Thumbnail
    
    func getFirstPageThumbnail(size: NSSize) -> NSImage? {
        guard let page = page(at: 0) else {
            return nil
        }
        
        return page.thumbnail(of: size, for: .mediaBox)
    }
    
}
