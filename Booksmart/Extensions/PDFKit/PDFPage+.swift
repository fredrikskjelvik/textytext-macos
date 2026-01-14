import PDFKit

extension PDFPage {
    
    /// Get the page number (0-indexed)
    var pageNumber: Int? {
        // pageNumber used 1-indexing, therefore subtracting one.
        guard let pageNumber = pageRef?.pageNumber else { return nil }
        return pageNumber - 1
    }
    
    /// Get an array of PDFAnnotation's of a specific sybtype
    func getAnnotations(of type: PDFAnnotationSubtype) -> [PDFAnnotation] {
        return annotations.filter { annotation in
            return annotation.subtype == type
        }
    }
    
}
