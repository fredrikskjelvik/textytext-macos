import SwiftUI
import PDFKit
import Cocoa
import Factory

struct PDFViewContainer: NSViewControllerRepresentable {
    @Injected(Container.realm) private var realm
    
	@EnvironmentObject var readerState: ReaderState
    
    var bookState: BookState {
        readerState.bookState
    }
    
    @Binding var canUndo: Bool
    @Binding var canRedo: Bool
	
	func makeNSViewController(context: Context) -> PDFViewController {
        let controller = PDFViewController(coordinator: context.coordinator)
        controller.setupPDF(document: readerState.document.book!.getPDFDocument()!)
        
        bookState.pdfView = controller.pdfView
        
        if let highlights = readerState.document.book?.highlights {
            bookState.pdfView!.addInitializationStep({ (pdfView) in
                pdfView.setHighlightsFromPersisted(codedHighlights: Array(highlights))
            })
        }
		
		return controller
	}
    	
	func updateNSViewController(_ nsViewController: PDFViewController, context: Context) {
        if let currentPageInPdfView = nsViewController.pdfView.currentPageIndex(),
           currentPageInPdfView != bookState.currentPage
        {
            nsViewController.pdfView.goToPage(bookState.currentPage)
        }
	}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, PDFViewContainerDelegate {
        @Injected(Container.realm) private var realm
        
        let parent: PDFViewContainer
        
        init(_ parent: PDFViewContainer) {
            self.parent = parent
        }
        
        func pageDidChange(page: Int) {
            self.parent.bookState.setPage(page)
        }
        
        func createFlashcardFromSelection(selection: String) {
            self.parent.readerState.createFlashcardFromSelection(selection: selection)
        }
        
        func onPageChangeUndoManagerCheckpoint(canUndo: Bool, canRedo: Bool) {
            self.parent.canUndo = canUndo
            self.parent.canRedo = canRedo
        }
        
        func persistHighlights(codedHighlights: [PDFHighlightAnnotation.CodedAnnotation]) {
            guard let book = parent.readerState.document.book else { return }
            guard let pageIndex = codedHighlights.first?.page else { return }
//            let realm = Container.realm.callAsFunction()
            
            try? realm.write {
                let keepHighlights = Array(book.highlights).filter({ $0.page != pageIndex })
                book.highlights.removeAll()
                book.highlights.append(objectsIn: keepHighlights)
                book.highlights.append(objectsIn: codedHighlights)
            }
        }
    }
}

protocol PDFViewContainerDelegate {
    var parent: PDFViewContainer { get }
    
    func pageDidChange(page: Int)
    func createFlashcardFromSelection(selection: String)
    func onPageChangeUndoManagerCheckpoint(canUndo: Bool, canRedo: Bool)
    func persistHighlights(codedHighlights: [PDFHighlightAnnotation.CodedAnnotation])
}
