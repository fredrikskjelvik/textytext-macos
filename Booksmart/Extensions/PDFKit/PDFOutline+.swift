import PDFKit

extension PDFOutline {
    func getPage() -> Int {
        guard let doc = document else {
            return -1
        }
        
        guard let destination = destination,
              let page = destination.page else {
            return -1
        }
        
        return doc.index(for: page)
    }
}
