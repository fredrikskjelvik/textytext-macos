import PDFKit

class PDFDocumentManager {
    let document: PDFDocument
    
    init(_ document: PDFDocument) {
        self.document = document
    }
    
    // MARK: Direct copy
    
    func page(at index: Int) -> PDFPage? {
        return document.page(at: index)
    }
    
    // MARK: Metadata
    
    func getMetadata(attributeKey: PDFDocumentAttribute) -> Any? {
        guard let attrs = document.documentAttributes else { return nil }
        
        return attrs[attributeKey]
    }
    
    func setMetadata(attributeKey: PDFDocumentAttribute, value: AnyHashable) {
        guard document.documentAttributes != nil else { return }
        
        document.documentAttributes![attributeKey] = value
    }
    
}
