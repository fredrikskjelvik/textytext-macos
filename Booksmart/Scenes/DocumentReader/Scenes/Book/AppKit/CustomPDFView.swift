import Cocoa
import PDFKit
import Combine

class CustomPDFView: PDFView {
    
    // MARK: Initialization

    var highlighter: PDFHighlighter!
    var containerDelegate: PDFViewContainerDelegate!
    var pageHopUndoManager: PageHopUndoManager!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    convenience init(frame frameRect: NSRect, coordinator: PDFViewContainerDelegate) {
        self.init(frame: frameRect)
        self.containerDelegate = coordinator
        self.highlighter = PDFHighlighter(self)
        self.pageHopUndoManager = PageHopUndoManager(containerDelegate)

        setupObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var _document: PDFDocumentManager!
    var _pages: PDFPagesManager!
    var _currentSelection: PDFSelectionManager? = nil
    var initialized = false
    
    /// This runs after PDF has been laid out on screen, and has initialized document etc.
    func initialize() {
        rescale()
        
        guard let document = document else { fatalError("Document not loaded when it definitely should be") }
        
        self._document = PDFDocumentManager(document)
        self._pages = PDFPagesManager(_document)
        
        for callback in queuedInitializationSteps
        {
            callback(self)
        }
        
        queuedInitializationSteps = []
        
        initialized = true
    }
    
    // MARK: Into manager methods
    
    func getCurrentPage() -> PDFPageManager? {
        guard let page = currentPage else { return nil }
        
        return _pages.allPages.first(where: { $0.page == page })
    }
    
    func convert(page: PDFPage) -> PDFPageManager {
        return _pages.allPages.first(where: { $0.page == page })!
    }
    
    // MARK: Observers
    
    var cancellable = Set<AnyCancellable>()

    /// Set up observers (on window resize, on page change, etc.)
    func setupObservers() {
        // Resizing window
        NotificationCenter.default
            .publisher(for: NSWindow.didResizeNotification)
            .sink() { _ in self.rescale() }
            .store(in: &cancellable)
        
        
        // On click zoom in button
        NotificationCenter.default
            .publisher(for: NSNotification.Name.DidRequestZoomIn)
            .sink() { _ in
                self.zoomIn(nil)
            }
            .store(in: &cancellable)
        
        // On click zoom out button
        NotificationCenter.default
            .publisher(for: NSNotification.Name.DidRequestZoomOut)
            .sink() { _ in
                self.zoomOut(nil)
            }
            .store(in: &cancellable)
        
        // On click redo button
        NotificationCenter.default
            .publisher(for: NSNotification.Name.DidRequestRedoPageHop)
            .filter() { _ in self.pageHopUndoManager.canRedo }
            .sink() { [weak self] _ in
                self?.pageHopUndoManager.redo()
            }
            .store(in: &cancellable)
        
        NotificationCenter.default
            .publisher(for: NSNotification.Name.DidRequestUndoPageHop)
            .filter() { _ in self.pageHopUndoManager.canUndo }
            .sink() { [weak self] _ in
                self?.pageHopUndoManager.undo()
            }
            .store(in: &cancellable)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onPageChange(notification:)), name: Notification.Name.PDFViewPageChanged, object: nil)
    }
    
    // MARK: Mouse events
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        onSelectionChange()
    }

    // MARK: Handle observers

    var notifyDelegateAboutPageChange = true
    
    /// On book page change
    @objc func onPageChange(notification: Notification) {
        if initialized == false {
            return
        }
        
        guard let page = getCurrentPage() else { return }
        
        if notifyDelegateAboutPageChange == false {
            notifyDelegateAboutPageChange = true
            return
        }
        
        containerDelegate.pageDidChange(page: page.pageNumber)
    }
    
    func setCurrentSelection() {
        if let currentSelection = currentSelection
        {
            _currentSelection = PDFSelectionManager(currentSelection, document: _document, pages: _pages)
        }
        else
        {
            _currentSelection = nil
        }
    }

    func onSelectionChange() {
        setCurrentSelection()
        
        guard let selection = _currentSelection,
              selection.pages.count == 1
        else { return }
        
        let page = selection.pages[0]

        let bounds = selection.bounds(for: page)
        let boundsAdjusted = convert(bounds, from: page.page)

        let popoverViewController = PDFViewSelectionToolbar(highlighter: highlighter)
            popoverViewController.selection = selection
        
        let popover = NSPopover()
            popover.contentViewController = popoverViewController
            popover.behavior = .transient

        popover.show(relativeTo: boundsAdjusted, of: self, preferredEdge: NSRectEdge.maxY)
    }

    // MARK: Menu

    // TODO: Use filtering to keep some of the OG menu items
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        let yellowMenuItem = NSMenuItem(title: "Yellow", action: #selector(highlightCurrentSelection(_:)), keyEquivalent: "")
            yellowMenuItem.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Yellow circle")
        menu.addItem(yellowMenuItem)

        let blueMenuItem = NSMenuItem(title: "Blue", action: #selector(highlightCurrentSelection(_:)), keyEquivalent: "")
            blueMenuItem.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Blue circle")
        menu.addItem(blueMenuItem)

        let greenMenuItem = NSMenuItem(title: "Green", action: #selector(highlightCurrentSelection(_:)), keyEquivalent: "")
            greenMenuItem.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Green circle")
        menu.addItem(greenMenuItem)

        let createFlashcardFromSelectionMenuItem = NSMenuItem(title: "Create Flashcard from Selection", action: #selector(createFlashcardFromSelection(_:)), keyEquivalent: "")
        menu.addItem(createFlashcardFromSelectionMenuItem)

        return menu
    }

    /// When user clicks on "Highlight" button in the context menu, highlight currently selected text
    @objc func highlightCurrentSelection(_ sender: NSMenuItem) {
        setCurrentSelection()
        guard let selection = _currentSelection else { return }

        let colorName = sender.title
        var color: NSColor
        switch colorName
        {
            case "Yellow":
                color = .systemYellow
            case "Blue":
                color = .systemBlue
            case "Green":
                color = .systemGreen
            default:
                color = .systemYellow
        }

        highlighter.highlight(selection: selection, color: color)
    }

    @objc func createFlashcardFromSelection(_ sender: NSMenuItem) {
        guard let selectedText = currentSelection?.string else { return }

        containerDelegate.createFlashcardFromSelection(selection: selectedText)
    }

    func rescale() {
        self.scaleFactor = scaleFactorForSizeToFit
    }

    @discardableResult
    func goToPage(_ pageIndex: Int, notifyDelegate: Bool = false) -> Bool {
        guard let doc = document else { return false }
        guard let page = doc.page(at: pageIndex) else { return false }
        guard let currentPageIndex = currentPageIndex() else { return false }
        
        pageHopUndoManager.registerUndo(withTarget: self as CustomPDFView, handler: { (targetSelf) in
            targetSelf.goToPage(currentPageIndex, notifyDelegate: true)
        })
        
        self.notifyDelegateAboutPageChange = notifyDelegate
        self.go(to: page)

        return true
    }
    
    func currentPageIndex() -> Int? {
        return self.currentPage?.pageNumber
    }
    
    // MARK: Persisted highlights
    
    func didUpdateHighlights(on page: PDFPageManager) {
        let codedHighlights = page.legitHighlights.map({ $0.getCoded() })
        
        containerDelegate.persistHighlights(codedHighlights: codedHighlights)
    }
    
    func setHighlightsFromPersisted(codedHighlights: [PDFHighlightAnnotation.CodedAnnotation]) {
        for highlight in codedHighlights
        {
            let pageIndex = highlight.page
            let page = _pages[pageIndex]
            
            page?.addHighlight(bounds: highlight.bounds, color: highlight.color)
        }
    }
    
    var queuedInitializationSteps = [(CustomPDFView) -> Void]()
    
    func addInitializationStep(_ callback: @escaping (CustomPDFView) -> Void) {
        queuedInitializationSteps.append(callback)
    }

}
