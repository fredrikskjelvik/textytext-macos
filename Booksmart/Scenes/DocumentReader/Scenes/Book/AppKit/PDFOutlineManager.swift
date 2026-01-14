import PDFKit

// TODO: Replace PDFOutline+ extension with this.
class PDFOutlineManager {
    var pdfView: CustomPDFView
    
    var root: PDFOutline? {
        guard let doc = pdfView.document else { return nil }
        return doc.outlineRoot
    }
    
    init(_ parent: CustomPDFView) {
        self.pdfView = parent
    }
}
