import Cocoa

class PopoverManager {
    private var textView: TextView
    
    private var blockStorage: TextBlockStorage {
        textView.blockStorage
    }
    
    private var inset: NSSize {
        textView.textContainerInset
    }
    
    init(textView: TextView) {
        self.textView = textView
        
        inlineStylingPopupController.delegate = blockStorage
        linkPopupController.delegate = blockStorage
        pageLinkPopupController.delegate = blockStorage
    }
    
    // MARK: Inline Styling Popup
    /// Basically mainly a property used in a mechanism to prevent the following: You copy in a link, the link popup controller appears after a small delay, but then copying in the
    /// link causes text selection which triggers the inline styling popup controller to appear, removing the link popup controller. There is probably a better way to handle this though.
    private var inlineStylingTimerTick = 0
    /// Popup that appears upon text selection for applying inline styling
    private var inlineStylingPopupController = InlineStylingPopupController()
    
    func displayInlineStylingPopup(selection: TextSelection) {
        // Only display it when text selection is within a single block
        guard case let .singleBlock(blockIndex, range) = selection, range.length != 0 else {
            return
        }
        
        // Give the inline styling controller information it needs
        inlineStylingPopupController.selectedRange = range
        inlineStylingPopupController.selectedBlockRange = blockIndex ..< blockIndex + 1
        inlineStylingPopupController.selectedLink = nil
        
        // Loop through distinct attribute runs
        // If a link is present in the selected range, add the link (as a URL) and the range of that link to the inline styling controller
        blockStorage.enumerateAttribute(.link, in: range, options: [], using: { value, range, stop in
            guard let link = value as? URL else {
                return
            }

            inlineStylingPopupController.selectedLink = (link, range)
            stop.pointee = true
        })
        
        blockStorage.enumerateAttribute(.pageLinkTo, in: range, using: { value, _, _ in
            guard let page = value as? Int else {
                return
            }
            
            inlineStylingPopupController.selectionPageLink = page
        })

        // Actually display and correctly place the inline styling view that was created here
        displayPopup(for: range, with: inlineStylingPopupController, preferredEdge: .minY)
    }
    
    // MARK: Link Popup
    /// Popup that appears upon copying in or creating a link, for setting the url and name
    private var linkPopupController = LinkPopupController()
    
    /// Request to open a link popup controller. Pass the information from current selection to the link popup controller. Display it via a method responsible
    /// for correct placement etc.
    /// - Parameters:
    ///   - range: range of current selection
    ///   - text: text in current selection
    ///   - url: url of the selected link, if any
    public func displayLinkPopup(for range: NSRange, text: String, url: URL? = nil) {
        if let url = url
        {
            displayLinkPopup(for: range, selection: .both(text, url.absoluteString))
        }
        else
        {
            displayLinkPopup(for: range, selection: LinkPopupController.SelectedText(text))
        }
    }
    
    public func displayLinkPopup(for range: NSRange, selection: LinkPopupController.SelectedText) {
        linkPopupController.setSelection(range: range, text: selection)
        displayPopup(for: range, with: linkPopupController, preferredEdge: .maxY)
    }
    
    //MARK: Page Link Popup
    
    /// Popup that appears to create a link to a page
    private var pageLinkPopupController = PageLinkPopupController()
    
    /// Request to open a page link popup controller. Pass the information from current selection to the page link popup controller. Display it via a method responsible
    /// for correct placement etc.
    /// - Parameters:
    ///   - range: range of current selection
    ///   - page: pageTo information in the current selection's NSAttributedString.Key
    public func displayPageLinkPopup(for range: NSRange, page: Int? = nil) {
        pageLinkPopupController.setSelection(range: range, page: page)
        
        displayPopup(for: range, with: pageLinkPopupController, preferredEdge: .maxY)
    }

    // MARK: General
    
    /// Last active popover
    private var lastPopover: NSPopover? = nil
    
    /// Display some popup, and place it correctly
    ///
    /// There are multiple possible popups (specified as argument)
    /// - one of them is for choosing inline styling/block type when some text has been selected)
    /// - the other is the block selection menu (when you type "/" at the beginning of a line)
    ///
    /// - Parameters:
    ///   - range:text selection range
    ///   - controller: controller of the popup to show
    ///   - edge: which side to show the popup (above, right side, etc)
    private func displayPopup(for range: NSRange, with controller: NSViewController, preferredEdge edge: NSRectEdge) {
        // If a popover already is open, close it and proceed
        if let popover = lastPopover
        {
            popover.performClose(nil)
            lastPopover = nil
        }
        
        let layoutManager = textView.layoutManager!
        let textContainer = textView.textContainer!

        // Get the NSRect covering the selected range of text (glyphRect), and then adjust its location to account for the text container
        // inset (adjustedRect)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let adjustedRect = glyphRect.offsetBy(dx: inset.width, dy: inset.height)

        let popover = NSPopover()
            popover.contentViewController = controller
            popover.behavior = .transient
            popover.show(relativeTo: adjustedRect, of: textView, preferredEdge: edge)
        
        lastPopover = popover
    }
    
    // MARK: Handling textView events
    
    func textViewDidChangeSelection(selection: TextSelection) {
        if let popover = lastPopover {
            popover.performClose(nil)
            lastPopover = nil
        }
        
        inlineStylingTimerTick += 1
        
        // Don't display the inline styling popup when in multiblock selection mode.
        guard case let .singleBlock(_, range) = selection, range.length != 0 else {
            return
        }
        
        let currentTick = inlineStylingTimerTick

        // TODO: This is a quick and dirty implementation. Replace it.
        DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(500))) {
            if currentTick == self.inlineStylingTimerTick {
                self.displayInlineStylingPopup(selection: selection)
            }
        }
    }
    
    func tick() {
        inlineStylingTimerTick += 1
    }
}
