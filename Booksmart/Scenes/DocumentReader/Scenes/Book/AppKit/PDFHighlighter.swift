import PDFKit

class PDFHighlighter {
    let pdfView: CustomPDFView

    init(_ pdfView: CustomPDFView) {
        self.pdfView = pdfView
    }

    func highlight(selection: PDFSelectionManager, color: NSColor = .yellow) {
        let selections = selection.selectionsByLine()
        
        // Get pages that are involved in the selection
        var selectionCoversPages = [PDFPageManager]()
        for selection in selections
        {
            for page in selection.pages
            {
                if !selectionCoversPages.contains(page)
                {
                    selectionCoversPages.append(page)
                }
            }
        }
        
        // Go page by page, applying process
        for page in selectionCoversPages
        {
            /// All highlights on current page
            let highlights = page.highlights
            /// All selections on current page
            let selections = selections.filter({ $0.pages[0] == page })
            
            /// All interactions on current page. Interaction = one selection rect + one or more highlights that it interacts with
            var interactions = InteractingSelectionAndHighlight.getInteractionsOnPage(selections: selections, highlights: highlights, page: page)
            var dropped = [InteractingSelectionAndHighlight]()
            
            // A highlight can turn out to be an insertion (adds some highlight) or deletion (removes some highlight or part of some
            // highlight), but you cannot know for sure until the end. Therefore, put actions that should happen in either case in
            // these separate arrays. The actions (methods) inside deferredInsertions can in fact be deletions (e.g. when extending a
            // highlight you delete the old higlight and add the union), but they run in case this highlighting session overall is an
            // insertion.
            var deferredDeletions = [() -> Void]()
            var deferredInsertions = [() -> Void]()
            
            // Case: Selections that are exactly equal to a certain highlight (bounds.equalTo)
            dropped = interactions.filter({ $0.selectionFullyCoversHighlight() == true })
            interactions = interactions.filter({ $0.selectionFullyCoversHighlight() == false })
            
            for interaction in dropped
            {
                if let highlight = interaction.highlights.first
                {
                    deferredDeletions.append({ page.removeAnnotation(highlight) })
                }
            }
            
            // Case: Selections that do not intersect with any highlight
            dropped = interactions.filter({ $0.highlights.count == 0 })
            interactions = interactions.filter({ $0.highlights.count != 0 })
            
            for interaction in dropped
            {
                deferredInsertions.append({ page.addHighlight(bounds: interaction.selectionBounds, color: color) })
            }
            
            // Case: Selections that are fully subsumed by a highlight
            dropped = interactions.filter({ $0.selectionSubsumedByHighlight() == true })
            interactions = interactions.filter({ $0.selectionSubsumedByHighlight() == false })
            
            for interaction in dropped
            {
                let highlightBounds = interaction.highlights[0].bounds
                let selectionBounds = interaction.selectionBounds
                
                let leftAnnotationBounds = NSRect(x: highlightBounds.minX, y: highlightBounds.minY, width: (selectionBounds.minX - highlightBounds.minX), height: highlightBounds.height)
    
                let rightAnnotationBounds = NSRect(x: highlightBounds.maxX, y: highlightBounds.minY, width: (selectionBounds.maxX - highlightBounds.maxX), height: highlightBounds.height)
                
                if leftAnnotationBounds.width > 1
                {
                    deferredDeletions.append({ page.addHighlight(bounds: leftAnnotationBounds, color: color) })
                }
                
                if rightAnnotationBounds.width > 1
                {
                    deferredDeletions.append({ page.addHighlight(bounds: rightAnnotationBounds, color: color) })
                }
                
                for highlight in interaction.highlights
                {
                    deferredDeletions.append({ page.removeAnnotation(highlight) })
                }
            }
            
            // Case: All remaining cases
            for interaction in interactions
            {
                let union = interaction.getUnion()

                deferredInsertions.append({ page.addHighlight(bounds: union, color: color) })

                for highlight in interaction.highlights
                {
                    deferredInsertions.append({ page.removeAnnotation(highlight) })
                }
            }
            
            // Apply changes, depending on whether it was an (overall) insertion or deletion
            if deferredInsertions.count > 0
            {
                for insertion in deferredInsertions
                {
                    insertion()
                }
            }
            else
            {
                for deletion in deferredDeletions
                {
                    deletion()
                }
            }
            
            pdfView.didUpdateHighlights(on: page)
        }
    }
}

fileprivate struct InteractingSelectionAndHighlight {
    var page: PDFPage
    var selection: PDFSelection
    var highlights: [PDFAnnotation]
    
    var selectionBounds: NSRect {
        selection.bounds(for: page)
    }
    
    /// The selection is exactly equal to the highlight
    func selectionFullyCoversHighlight() -> Bool {
        guard highlights.count == 1, let highlight = highlights.first else { return false }
        
        return selectionBounds.equalTo(highlight.bounds)
    }
    
    /// The highlight contains selection
    func selectionSubsumedByHighlight() -> Bool {
        guard highlights.count == 1, let highlight = highlights.first else { return false }
        
        return highlight.bounds.contains(selectionBounds)
    }
    
    /// Get the union of the selection and the highlight(s)
    func getUnion() -> NSRect {
        var bounds: NSRect = selection.bounds(for: page)
        
        for highlight in highlights
        {
            bounds = bounds.union(highlight.bounds)
        }
        
        return bounds
    }
    
    /// Given a set of selections and existing highlights on a particular page, get an array of (this class) with each element containing the following information: a selection + the highlight(s) it intersects
    /// - Parameters:
    ///   - selections: all selections on this page
    ///   - highlights: all existing highlights on this page
    ///   - page: a pdf page
    /// - Returns: [InteractingSelectionAndHighlight]
    static func getInteractionsOnPage(selections: [PDFSelectionManager], highlights: [PDFAnnotation], page: PDFPageManager) -> [InteractingSelectionAndHighlight] {
        var interactions = [InteractingSelectionAndHighlight]()
        
        for selection in selections
        {
            var interactingHighlights = [PDFAnnotation]()
            for highlight in highlights
            {
                if selection.bounds(for: page).intersects(highlight.bounds)
                {
                    interactingHighlights.append(highlight)
                }
            }
            
            interactions.append(InteractingSelectionAndHighlight(page: page.page, selection: selection.selection, highlights: interactingHighlights))
        }
        
        return interactions
    }
}
