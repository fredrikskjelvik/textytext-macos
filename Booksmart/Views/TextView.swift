import Cocoa
import UniformTypeIdentifiers

extension NSString {
    func lineRanges() -> [NSRange] {
        let fullRange = NSRange(location: 0, length: length)
        var ranges: [NSRange] = []

        enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired], using: {_, range, _, _ in
            ranges.append(range)
        })

        return ranges
    }
}

class BlockUndoManager : UndoManager {
    override init() {
        super.init()
        groupsByEvent = false
    }

    override func undo() {
        if groupingLevel >= 1 {
            super.endUndoGrouping()
        }

        super.undo()
    }

    override func undoNestedGroup() {
        if groupingLevel >= 1 {
            super.endUndoGrouping()
        }

        super.undoNestedGroup()
    }

    public override func registerUndo(withTarget target: Any, selector: Selector, object anObject: Any?) {
        if groupingLevel == 0 {
            super.beginUndoGrouping()

            if isUndoing == false, isRedoing == false, let blockStorage = target as? TextBlockStorage {
                blockStorage.registerBlockStateUndoHandler()
            }
        }

        super.registerUndo(withTarget: target, selector: selector, object: anObject)
    }
}

class DragSelectIndicatorView : NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        if let layer = self.layer {
            layer.backgroundColor = CGColor(srgbRed: 200/255, green: 225/255, blue: 255/255, alpha: 0.25)
            layer.borderColor = CGColor(srgbRed: 175/255, green: 200/255, blue: 255/255, alpha: 0.75)
            layer.borderWidth = 1
            layer.cornerRadius = 4
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate func typeIndentifier(for url: URL) -> UTType? {
    if let resources = try? url.resourceValues(forKeys: [.typeIdentifierKey]),
       let typeIdentifier = resources.typeIdentifier {
        return UTType(typeIdentifier)
    } else {
        return UTType(filenameExtension: url.pathExtension)
    }
}

fileprivate func pasteboardContainsImage(_ pasteboard: NSPasteboard) -> Bool {
    guard let types = pasteboard.types else {
        return false
    }

    let imageTypes: [NSPasteboard.PasteboardType] = [
        .png,
        NSPasteboard.PasteboardType(UTType.jpeg.description),
        .tiff,
        .pdf
    ]

    for supportedType in imageTypes {
        if types.contains(supportedType) {
            return true
        }
    }

    if let url = NSURL(from: pasteboard) as URL?, let type = typeIndentifier(for: url) {
        return type.conforms(to: .image)
    }

    return false
}

enum DragType {
    case `default`
    case block
    case image

    init(info: NSDraggingInfo) {
        if info.draggingSource is TextView {
            self = .block
        } else if pasteboardContainsImage(info.draggingPasteboard) {
            self = .image
        } else {
            self = .default
        }
    }
 }

class DraggedBlockDropIndicator : NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        if let layer = self.layer {
            layer.backgroundColor = CGColor(srgbRed: 0, green: 145 / 255, blue: 248 / 255, alpha: 0.8)
            layer.cornerRadius = frame.height / 2
        }
    }

    public required init?(coder: NSCoder) {
        return nil
    }
}

enum TextSelection {
    case none
    case multiBlock(Range<Int>)
    case singleBlock(Int, NSRange)

    var isMultiBlock: Bool {
        if case .multiBlock = self {
            return true
        } else {
            return false
        }
    }

    var isSingleBlock: Bool {
        if case .singleBlock = self {
            return true
        } else {
            return false
        }
    }

    func selectedBlocks() -> Range<Int> {
        switch self {
        case .multiBlock(let range):
            return range

        case .singleBlock(let blockIndex, _):
            return blockIndex ..< blockIndex

        case .none:
            return -1 ..< -1
        }
    }
}

class TextView: NSTextView, NSTextViewDelegate, BlockHoverViewDelegate {
	// MARK: Properties
    var blockStorage: TextBlockStorage

    // Note: Using an internal UndoManager like this will cause problems if we want to share the undo stack with other UI elements.
    //       If that use case arises, push this up to the NSWindow level and pass down a reference.
    private var blockUndoManager: BlockUndoManager

    public var deferredSelection: NSRange? = nil
    private var lastEdit: (block: Block, edit: BlockEdit)? = nil
    private(set) public var editCount: Int = 0

    private var inlineStylingTimerTick = 0
    private var inlineStylingPopupController = InlineStylingPopupController()
    private var linkPopupController = LinkPopupController()

    private var lastPopover: NSPopover? = nil
    private var blockHoverViewController = BlockHoverViewController()
    private var blockMenuViewController = BlockMenuViewController()

    private var isMouseDown = false
    private var isDragging = false

    // TODO: Encapsulate temporary event state in structs
    private var mouseEventTick = 0
    private var dragForceMultiblock = false
    private var dragOriginPoint = NSPoint()
    private var dragOriginCharacterIndex = 0
    private var dragOriginBlock: Block! = nil
    private var dragOriginBlockRange = NSRange()
    private var dragOriginBlockRect = NSRect()
    private var dragTextRect = NSRect()
    private var dragSelectIndicator: DragSelectIndicatorView? = nil
    private var dragType: DragType = .default

    private var mouseOverBlock: Block? = nil
    private var mouseOverBlockRect: NSRect? = nil

    private var draggedBlockDropIndicator: DraggedBlockDropIndicator? = nil
    private var draggedBlocks: Range<Int>? = nil

    public var selection: TextSelection = .none

    public override var textContainerInset: NSSize {
        didSet {
            let lineHoverView = blockHoverViewController.view
            lineHoverView.frame.origin = NSPoint(x: textContainerInset.width - lineHoverView.frame.size.width,
                                                 y: textContainerInset.height)
        }
    }

    private var actualInsertionPointColor = NSColor.black

    public var isInsertionPointHidden = false {
        didSet {
            if isInsertionPointHidden {
                super.insertionPointColor = NSColor.clear
            } else {
                super.insertionPointColor = actualInsertionPointColor
            }
        }
    }

    public override var insertionPointColor: NSColor {
        get {
            return super.insertionPointColor
        }

        set {
            actualInsertionPointColor = newValue

            if isInsertionPointHidden == false {
                super.insertionPointColor = newValue
            }
        }
    }

	// MARK: Initialization

    override init(frame: NSRect) {
        blockUndoManager = BlockUndoManager()

        let layoutManager = BlockLayoutManager()
        blockStorage = TextBlockStorage()
        layoutManager.allowsNonContiguousLayout = true
        blockStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: frame.size)
        textContainer.widthTracksTextView = true

        textContainer.containerSize = NSSize(
            width: frame.width,
            height: CGFloat.greatestFiniteMagnitude
        )

        layoutManager.addTextContainer(textContainer)
        layoutManager.delegate = blockStorage

        blockMenuViewController.delegate = blockStorage
        inlineStylingPopupController.delegate = blockStorage
        linkPopupController.delegate = blockStorage

        super.init(frame: frame, textContainer: textContainer)
        self.font = NSFont.systemFont(ofSize: TextBlock.fontSize)
        self.subviews = [blockHoverViewController.view]
        self.delegate = self

        blockStorage.textView = self
        blockHoverViewController.delegate = self

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(willUndoOrRedoChange(_:)), name: .NSUndoManagerWillUndoChange, object: blockUndoManager)
        notificationCenter.addObserver(self, selector: #selector(willUndoOrRedoChange(_:)), name: .NSUndoManagerWillRedoChange, object: blockUndoManager)
        notificationCenter.addObserver(self, selector: #selector(didUndoOrRedoChange(_:)), name: .NSUndoManagerDidUndoChange, object: blockUndoManager)
        notificationCenter.addObserver(self, selector: #selector(didUndoOrRedoChange(_:)), name: .NSUndoManagerDidRedoChange, object: blockUndoManager)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func willUndoOrRedoChange(_ : Notification) {
        editCount += 1
    }

    @objc func didUndoOrRedoChange(_ : Notification) {
        editCount -= 1
        blockStorage.layoutDeferred()
        blockStorage.printBlocks()
    }

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func menu(for event: NSEvent) -> NSMenu? {
		let menu = NSMenu()
            menu.addItem(withTitle: "Start Speaking", action: #selector(startSpeaking(_:)), keyEquivalent: "")
		return menu
	}

    private func displayInlineStylingPopup() {
        guard case let .singleBlock(blockIndex, range) = selection, range.length != 0 else {
            return
        }

        inlineStylingPopupController.selectedRange = selectedRange
        inlineStylingPopupController.selectedBlockRange = blockIndex ..< blockIndex + 1
        inlineStylingPopupController.selectedLink = nil

        blockStorage.enumerateAttribute(.link, in: range, options: [], using: {value, range, stop in
            guard let link = value as? URL else {
                return
            }

            inlineStylingPopupController.selectedLink = (link, range)
            stop.pointee = true
        })

        displayPopup(for: selectedRange, with: inlineStylingPopupController, preferredEdge: .minY)
    }

    public func displayLinkPopup(for range: NSRange, text: String, url: URL? = nil) {
        if let url = url {
            linkPopupController.setSelection(range: range, text: .both(text, url.absoluteString))
        } else {
            linkPopupController.setSelection(range: range, text: LinkPopupController.SelectedText(text))
        }

        displayPopup(for: range, with: linkPopupController, preferredEdge: .maxY)
    }

    private func displayPopup(for range: NSRange, with: NSViewController, preferredEdge edge: NSRectEdge) {
        if let popover = lastPopover {
            popover.performClose(nil)
            lastPopover = nil
        }

        guard let textContainer = self.textContainer,
              let layoutManager = self.layoutManager else {
            return
        }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        let inset = textContainerInset
        let adjustedRect = glyphRect.offsetBy(dx: inset.width, dy: inset.height)

        let popover = NSPopover()
        popover.contentViewController = with
        popover.behavior = .transient
        popover.show(relativeTo: adjustedRect, of: self, preferredEdge: edge)
        lastPopover = popover
    }

    public func textViewDidChangeSelection(_ notification: Notification) {
        if editCount == 0 {
            updateTypingAttributes()
        }

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
                self.displayInlineStylingPopup()
            }
        }
    }

    public func undoManager(for view: NSTextView) -> UndoManager? {
        return blockUndoManager
    }

    override func breakUndoCoalescing() {
        if blockUndoManager.groupingLevel >= 1 {
            blockUndoManager.endUndoGrouping()
        }

        super.breakUndoCoalescing()
    }

    private func blockForKeybinding() -> (Block, Int)? {
        let selected = selectedRange()

        if selected.length != 0 {
            return nil
        }

        let block = blockStorage.block(at: selected.location)
        return (block, selected.location - block.offset)
    }

    private func handleInsertedSlash(at location: Int, in block: Block) {
        guard let event = NSApp.currentEvent, event.type == .keyDown, event.characters == "/" else {
            return
        }

        let textRange = block.textRange

        if textRange.location == location {
            blockMenuViewController.display(in: self, atCharacter: location, inBlock: block)
        }
    }

    public func beginEditing() {
        blockStorage.beginEditing()
        editCount += 1
    }

    public func endEditing() {
        editCount -= 1
        blockStorage.endEditing()

        if editCount == 0, let selection = deferredSelection {
            deferredSelection = nil
            setSelectedRange(selection)
        }
    }

    @discardableResult override func shouldChangeText(in replacementRange: NSRange, replacementString: String?) -> Bool {
        editCount += 1

        guard editCount == 1, let string = replacementString else {
            return super.shouldChangeText(in: replacementRange, replacementString: replacementString)
        }

        deferredSelection = nil
        
        let edit: BlockEdit
        let block = blockStorage.block(at: replacementRange.location)
        let blockRange = block.range
        let blockEnd = blockRange.upperBound
        let replacementRangeEnd = replacementRange.upperBound

        if replacementRangeEnd > blockEnd {
            edit = .multiBlockEdit(replacementRange, string)
        } else if replacementRangeEnd == blockEnd && string.isEmpty && replacementRange.length == 1 {
            edit = .deleteLastCharacter(replacementRange)
        } else if let firstNewline = string.firstIndex(where: {$0.isNewline}) {
            edit = .replaceWithLines(replacementRange, string, firstNewline)
        } else if replacementRange.length != 0 {
            edit = .replace(replacementRange, string)
        } else {
            edit = .insert(replacementRange, string)
        }

        lastEdit = (block, edit)
        block.willEdit(edit)

        return super.shouldChangeText(in: replacementRange, replacementString: replacementString)
    }

    private func updateTypingAttributes() {
        switch selection {
        case .multiBlock:
            return

        case .singleBlock(let blockIndex, _):
            let block = blockStorage.blocks[blockIndex]

            if block.length == (blockIndex != (blockStorage.blocks.count - 1) ? 1 : 0) {
                typingAttributes = block.style.attributes
            }

        case .none:
            let range = selectedRange()

            if range.length != 0 {
                return
            }

            if range.location == blockStorage.length {
                if let block = blockStorage.blocks.last, block.length == 0 {
                    typingAttributes = block.style.attributes
                }
            } else if blockStorage.mutableString.compare("\n", options: .literal, range: NSRange(location: range.location, length: 1)) == .orderedSame {
                let block = blockStorage.block(at: range.location)

                if block.length == 1 {
                    typingAttributes = block.style.attributes
                }
            }
        }
    }

    override func didChangeText() {
        editCount -= 1

        guard editCount == 0, let (block, edit) = lastEdit else {
            return super.didChangeText()
        }

        blockHoverViewController.setHidden(true)

        beginEditing()
        block.didEdit(edit)
        endEditing()

        blockStorage.layoutDeferred()
        blockStorage.printBlocks()

        lastEdit = nil
        super.didChangeText()

        if let selection = deferredSelection {
            deferredSelection = nil
            setSelectedRange(selection)
        }

        if blockMenuViewController.isOpen {
            blockMenuViewController.didEdit(block: block, edit: edit)
        } else if case let .insert(range, string) = edit, string == "/" {
            handleInsertedSlash(at: range.location, in: block)
        }

        updateTypingAttributes()
    }

    override func insertTab(_ sender: Any?) {
        if let (block, location) = blockForKeybinding(), block.insertTab(at: location) {
            return
        }

        super.insertTab(sender)
    }

    override func insertBacktab(_ sender: Any?) {
        if let (block, location) = blockForKeybinding(), block.insertBacktab(at: location) {
            return
        }

        super.insertBacktab(sender)
    }

    override func insertNewline(_ sender: Any?) {
        if let (block, location) = blockForKeybinding(), block.insertNewline(at: location) {
            return
        }

        super.insertNewline(sender)
    }

    override func deleteForward(_ sender: Any?) {
        if let (block, location) = blockForKeybinding(), block.deleteForward(at: location) {
            return
        }

        super.deleteForward(sender)
    }

    override func deleteBackward(_ sender: Any?) {
        if let (block, location) = blockForKeybinding(), block.deleteBackward(at: location) {
            return
        }

        super.deleteBackward(sender)
    }

    /// Returns the portion of the view that contains text.
    /// Accounts for text container insets and empty space at the end of the document.
    private func textRect() -> NSRect {
        let inset = textContainerInset
        var textHeight: CGFloat = 0

        if let layoutManager = self.layoutManager {
            let glyphCount = layoutManager.numberOfGlyphs

            if glyphCount > 0 {
                let lastLine = layoutManager.lineFragmentRect(forGlyphAt: glyphCount - 1, effectiveRange: nil)
                let extraLine = layoutManager.extraLineFragmentRect
                textHeight = max(lastLine.maxY, extraLine.maxY)
            }
        }

        return NSRect(x: inset.width, y: inset.height, width: frame.size.width - inset.width, height: textHeight)
    }

    func setSelectedBlocks(_ blockRange: Range<Int>, range: NSRange, affinty: NSSelectionAffinity = .downstream, stillSelecting: Bool = false) {
        needsDisplay = true
        selection = .multiBlock(blockRange)
        super.setSelectedRanges([NSValue(range: range)], affinity: affinty, stillSelecting: stillSelecting)
    }

    func setSelectedBlocks(_ blockRange: Range<Int>, affinty: NSSelectionAffinity = .downstream, stillSelecting: Bool = false) {
        let range = blockStorage.characterRange(forBlockRange: blockRange)
        setSelectedBlocks(blockRange, range: range, affinty: affinty, stillSelecting: stillSelecting)
    }

    private func adjustSelectionBackward(_ range: NSRange, startingWith initialBlock: Block) -> (Int, NSRange) {
        var block = initialBlock
        var blockIndex = initialBlock.index

        while true {
            if let adjusted = block.adjustSelection(range, inDirection: .downstream) {
                return (blockIndex, adjusted)
            }

            if blockIndex == 0 {
                return adjustSelectionForward(range, startingWith: initialBlock)
            }

            blockIndex -= 1

            let prevBlock = blockStorage.blocks[blockIndex]
            prevBlock.offset = block.offset - prevBlock.length
            prevBlock.index = blockIndex
            block = prevBlock
        }
    }

    private func adjustSelectionForward(_ range: NSRange, startingWith initialBlock: Block) -> (Int, NSRange) {
        let blockCount = blockStorage.blocks.count
        var block = initialBlock
        var blockIndex = initialBlock.index

        while true {
            if let adjusted = block.adjustSelection(range, inDirection: .upstream) {
                return (blockIndex, adjusted)
            }

            blockIndex += 1

            if blockIndex == blockCount {
                return (blockCount - 1, NSRange(location: blockStorage.length, length: 0))
            }

            let nextBlock = blockStorage.blocks[blockIndex]
            nextBlock.offset = block.offset + block.length
            nextBlock.index = blockIndex
            block = nextBlock
        }
    }

    func setSelectedRange(_ range: NSRange, in blockIndex: Int, affinity: NSSelectionAffinity = .downstream, stillSelecting: Bool = false) {
        needsDisplay = needsDisplay || selection.isSingleBlock == false

        let block = blockStorage.blocks[blockIndex]
        let adjusted: (index: Int, range: NSRange)

        if range.location < selectedRange().location {
            adjusted = adjustSelectionBackward(range, startingWith: block)
        } else {
            adjusted = adjustSelectionForward(range, startingWith: block)
        }

        selection = .singleBlock(adjusted.index, adjusted.range)
        super.setSelectedRanges([NSValue(range: adjusted.range)], affinity: affinity, stillSelecting: stillSelecting)

        if block.length <= 1 {
            typingAttributes = block.style.attributes
        }
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        assert(ranges.count <= 1, "Support for multiple selections not implemented")

        if ranges.isEmpty == false && editCount == 0 {
            let range = ranges[0].rangeValue

            if range.length == 0 {
                let block = blockStorage.block(at: range.location)
                return setSelectedRange(range, in: block.index, affinity: affinity, stillSelecting: stillSelecting)
            }

            if case let .singleBlock(blockIndex, _) = selection {
                return setSelectedRange(range, in: blockIndex, affinity: affinity, stillSelecting: stillSelecting)
            }
        }

        needsDisplay = needsDisplay || selection.isMultiBlock
        selection = .none

        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // NSTextView returns nil for points that lie within the text container inset, that means that by default we don't
        // get mouse events for clicks in that happen in the margin. We need to handle clicks in the margins as part of our
        // selection handling, so we override the default behavior here.
        if frame.contains(point) == false {
            return nil
        }

        let converted: NSPoint

        if let superview = self.superview {
            converted = superview.convert(point, to: self)
        } else {
            converted = convert(point, to: nil)
        }

        for view in subviews {
            if let hit = view.hitTest(converted) {
                return hit
            }
        }

        return self
    }

    override func mouseDown(with event: NSEvent) {
        blockMenuViewController.dismiss()
        mouseEventTick += 1

        let point = convert(event.locationInWindow, to: nil)
        let characterIndex = characterIndexForInsertion(at: point)
        let block = blockStorage.block(at: characterIndex)

        isMouseDown = true

        var blockRect = (layoutManager as? BlockLayoutManager)?.boundingRect(forBlock: block) ?? NSRect()
        blockRect.origin.y += textContainerInset.height
        blockRect.size.width = frame.size.width

        setSelectedRange(NSRange(location: characterIndex, length: 0), in: block.index)

        dragTextRect = textRect()
        dragOriginPoint = point
        dragOriginBlock = block
        dragOriginCharacterIndex = characterIndex
        dragOriginBlockRange = block.range
        dragOriginBlockRect = blockRect
        dragForceMultiblock = dragTextRect.contains(point) == false || block.isTextSelectable == false
    }

    private func mouseDragged(inSingleBlockTo point: NSPoint, atCharacterIndex characterIndex: Int) {
        if let indicator = dragSelectIndicator {
            indicator.isHidden = true
        }

        if characterIndex > dragOriginCharacterIndex {
            let range = NSRange(location: dragOriginCharacterIndex, length: characterIndex - dragOriginCharacterIndex)
            setSelectedRange(range, in: dragOriginBlock.index, affinity: .upstream, stillSelecting: true)
        } else {
            let range = NSRange(location: characterIndex, length: dragOriginCharacterIndex - characterIndex)
            setSelectedRange(range, in: dragOriginBlock.index, affinity: .downstream, stillSelecting: true)
        }
    }

    private func mouseDragged(inMultipleBlocksTo point: NSPoint, atCharacterIndex characterIndex: Int) {
        let indicatorFrame = NSRect(x: min(dragOriginPoint.x, point.x),
                                    y: min(dragOriginPoint.y, point.y),
                                    width: abs(dragOriginPoint.x - point.x),
                                    height: abs(dragOriginPoint.y - point.y))

        let dragOriginBlockIndex = dragOriginBlock.index

        if indicatorFrame.intersects(dragTextRect) {
            let blockAtPoint = blockStorage.block(at: characterIndex)
            let range = NSUnionRange(blockAtPoint.range, dragOriginBlockRange)
            let blockAtPointIndex = blockAtPoint.index

            if blockAtPointIndex < dragOriginBlockIndex {
                let blockRange = blockAtPointIndex ..< (dragOriginBlockIndex + 1)
                setSelectedBlocks(blockRange, range: range, affinty: .upstream, stillSelecting: true)
            } else {
                let blockRange = dragOriginBlockIndex ..< (blockAtPointIndex + 1)
                setSelectedBlocks(blockRange, range: range, affinty: .downstream, stillSelecting: true)
            }
        } else {
            let range = NSRange(location: dragOriginCharacterIndex, length: 0)
            setSelectedRange(range, in: dragOriginBlockIndex, affinity: .downstream, stillSelecting: true)
        }

        if let indicator = dragSelectIndicator {
            indicator.frame = indicatorFrame
            indicator.isHidden = false
        } else {
            let indicatorView = DragSelectIndicatorView(frame: indicatorFrame)
            dragSelectIndicator = indicatorView
            addSubview(indicatorView)
            isInsertionPointHidden = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if isMouseDown == false {
            return
        }

        let point = convert(event.locationInWindow, to: nil)
        mouseEventTick += 1

        // Mouse drag events are pretty sensitive. Wait until the mouse has moved some threshold value away
        // from the original mouse down point before we start dragging.
        if isDragging == false {
            if point.distance(from: dragOriginPoint) < 2 {
                return
            }

            isDragging = true
        }

        let characterIndex = characterIndexForInsertion(at: point)

        if dragForceMultiblock || dragOriginBlockRect.contains(point) == false {
            mouseDragged(inMultipleBlocksTo: point, atCharacterIndex: characterIndex)
        } else {
            mouseDragged(inSingleBlockTo: point, atCharacterIndex: characterIndex)
        }

        if visibleRect.contains(point) == false && autoscroll(with: event) {
            let currentTick = mouseEventTick

            // We need to call autoscroll() repeatedly here, but mouseDragged events only fire when the mouse has
            // moved, so we use a timer here to continue autoscrolling even when the mouse is stationary.
            DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(12))) {
                if self.mouseEventTick == currentTick {
                    self.mouseDragged(with: event)
                }
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        mouseEventTick += 1
        isMouseDown = false

        if let indicator = dragSelectIndicator {
            indicator.removeFromSuperview()
            dragSelectIndicator = nil
            isInsertionPointHidden = false
            updateInsertionPointStateAndRestartTimer(true)
        }

        if isDragging {
            isDragging = false
            super.setSelectedRanges([NSValue(range: selectedRange())], affinity: selectionAffinity, stillSelecting: false)
        } else if event.clickCount == 2 {
            selectWord(forCharacter: dragOriginCharacterIndex, inBlock: dragOriginBlock)
        } else if dragOriginCharacterIndex < blockStorage.length {
            let attributes = blockStorage.attributes(at: dragOriginCharacterIndex, effectiveRange: nil)

            if let link = attributes[.link] as? URL {
                if NSWorkspace.shared.open(link) == false {
                    NSSound.beep()
                }
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        blockHoverViewController.setHidden(true)
    }

    override func mouseMoved(with event: NSEvent) {
        guard let layoutManager = self.layoutManager as? BlockLayoutManager else {
            return
        }

        let location = convert(event.locationInWindow, to: nil)

        if let oldMouseRect = mouseOverBlockRect, location.y >= oldMouseRect.origin.y && location.y <= oldMouseRect.maxY {
            blockHoverViewController.setHidden(false)
            return
        }

        let character = characterIndexForInsertion(at: location)
        let block = blockStorage.block(at: character)
        let inset = textContainerInset

        var blockRect = layoutManager.boundingRect(forBlock: block)
        blockRect.origin.y += inset.height
        blockRect.origin.x = inset.width

        if location.y >= blockRect.origin.y && location.y <= blockRect.maxY {
            blockHoverViewController.view.frame.origin.y = blockRect.origin.y
            blockHoverViewController.setHidden(false)
            mouseOverBlockRect = blockRect
            mouseOverBlock = block
        } else {
            blockHoverViewController.setHidden(true)
            mouseOverBlockRect = nil
            mouseOverBlock = nil
        }
    }

    /// Selects the word that contains the given character index.
    ///
    /// - Parameter characterIndex: Character index in the text storage.
    /// - Parameter block: The block that contains the character. Selections are limited to within this block.
    private func selectWord(forCharacter characterIndex: Int, inBlock block: Block) {
        var selection = NSRange(location: characterIndex, length: 0)
        let string = blockStorage.mutableString

        let blockRange = block.range
        let searchRange: NSRange

        if block.isSingleLine {
            searchRange = blockRange
        } else {
            let lineRange = string.lineRange(for: selection)
            let location = max(blockRange.location, lineRange.location)
            let length = min(blockStorage.length - location, lineRange.length)
            searchRange = NSRange(location: location, length: length)
        }

        blockStorage.mutableString.enumerateSubstrings(in: searchRange, options: [.byWords, .substringNotRequired]) {_, range, _, stop in
            if range.contains(characterIndex) {
                selection = range
                stop.pointee = true
            }
        }

        setSelectedRange(selection, in: block.index)
    }

    private func moveAndModifyBlockSelection(_ selectedBlocks: Range<Int>, inDirection affinity: NSSelectionAffinity) {
        let delta = affinity == .upstream ? -1 : 1
        let oldAffinity = selectedBlocks.count == 1 ? affinity : selectionAffinity

        let newSelection: Range<Int>
        let newAffinity: NSSelectionAffinity

        if oldAffinity == .upstream {
            newSelection = max(selectedBlocks.startIndex + delta, 0) ..< selectedBlocks.upperBound
        } else {
            newSelection = selectedBlocks.startIndex ..< min(selectedBlocks.upperBound + delta, blockStorage.blocks.count)
        }

        if newSelection.count == 1 {
            newAffinity = affinity
        } else {
            newAffinity = oldAffinity
        }

        setSelectedBlocks(newSelection, affinty: newAffinity, stillSelecting: false)
    }

    private func selectedBlocks() -> Range<Int> {
        switch selection {
        case .multiBlock(let blockRange):
            return blockRange

        case .singleBlock(let blockIndex, _):
            return blockIndex ..< blockIndex + 1

        case .none:
            return blockStorage.blockRange(for: selectedRange())
        }
    }

    private func moveAndModifySelection(with command: Selector, inDirection direction: NSSelectionAffinity) {
        let selected: NSRange
        let selectedBlock: Block

        switch selection {
        case .multiBlock(let blockRange):
            return moveAndModifyBlockSelection(blockRange, inDirection: direction)

        case .singleBlock(let blockIndex, let characterRange):
            selected = characterRange
            selectedBlock = blockStorage.blocks[blockIndex]

        case .none:
            selected = selectedRange()
            selectedBlock = blockStorage.block(at: selected.location)
            selection = .singleBlock(selectedBlock.index, selected)
        }

        // Transition to a multi block seleciton when we can't extend the selection any further.
        if selectedBlock.canExtendSelection(selected, inDirection: direction) == false {
            let blockIndex = selectedBlock.index
            let blockRange = blockIndex ..< (blockIndex + 1)
            return setSelectedBlocks(blockRange, affinty: direction, stillSelecting: false)
        }

        super.doCommand(by: command)
    }

    override func doCommand(by selector: Selector) {
        let isBlockMenuOpen = blockMenuViewController.isOpen

        if isBlockMenuOpen && blockMenuViewController.handle(command: selector) {
            return
        }

        switch selector {
        case #selector(moveUpAndModifySelection(_:)),
             #selector(moveLeftAndModifySelection(_:)),
             #selector(moveWordLeftAndModifySelection(_:)),
             #selector(moveToLeftEndOfLineAndModifySelection(_:)),
             #selector(moveToBeginningOfParagraphAndModifySelection(_:)):
            moveAndModifySelection(with: selector, inDirection: .upstream)

        case #selector(moveDownAndModifySelection(_:)),
             #selector(moveRightAndModifySelection(_:)),
             #selector(moveWordRightAndModifySelection(_:)),
             #selector(moveToRightEndOfLineAndModifySelection(_:)),
             #selector(moveToEndOfParagraphAndModifySelection(_:)):
            moveAndModifySelection(with: selector, inDirection: .downstream)

        case #selector(moveToBeginningOfDocumentAndModifySelection(_:)):
            setSelectedBlocks(0 ..< selectedBlocks().upperBound, affinty: .upstream, stillSelecting: false)

        case #selector(moveToEndOfDocumentAndModifySelection(_:)):
            setSelectedBlocks(selectedBlocks().lowerBound ..< blockStorage.blocks.count, affinty: .downstream, stillSelecting: false)

        default:
            super.doCommand(by: selector)
        }

        if isBlockMenuOpen {
            blockMenuViewController.didCommand(by: selector)
        }
    }

    private func dragIndicatorPosition(location: NSPoint, block: Block, layoutManager: BlockLayoutManager) -> (frame: NSRect, blockIndex: Int)? {
        let inset = textContainerInset
        let width = frame.size.width - (inset.width * 2)

        let blockIndex = block.index
        let blockBeforeIndex = blockIndex - 1
        let blockAfterIndex = blockIndex + 1

        var blockRect = layoutManager.boundingRect(forBlock: block)

        if blockBeforeIndex >= 0 {
            let blockBefore = blockStorage.blocks[blockBeforeIndex]
            let blockBeforeRect = layoutManager.boundingRect(forBlock: blockBefore)
            let gap = blockBeforeRect.maxY - blockRect.origin.y
            let gapMidpoint = gap / 2

            blockRect.origin.y -= gapMidpoint
            blockRect.size.height += gapMidpoint
        }

        if blockAfterIndex < blockStorage.blocks.count {
            let blockAfter = blockStorage.blocks[blockAfterIndex]
            let blockAfterRect = layoutManager.boundingRect(forBlock: blockAfter)
            let gap = blockAfterRect.origin.y - blockRect.maxY
            let gapMidpoint = gap / 2

            blockRect.size.height += gapMidpoint
        }

        blockRect.origin.y += inset.height

        if location.y < blockRect.midY {
            return (NSRect(x: inset.width, y: blockRect.origin.y - 2, width: width, height: 4), blockIndex)
        } else {
            return (NSRect(x: inset.width, y: blockRect.maxY - 2, width: width, height: 4), blockAfterIndex)
        }
    }

    private func dragIndicatorPosition(draggingAt location: NSPoint, inBlock block: Block, layoutManager: BlockLayoutManager) -> (frame: NSRect, blockIndex: Int) {
        let inset = textContainerInset
        let width = frame.size.width - (inset.width * 2)

        let blockIndex = block.index
        let blockBeforeIndex = blockIndex - 1
        let blockAfterIndex = blockIndex + 1

        var blockRect = layoutManager.boundingRect(forBlock: block)

        if blockBeforeIndex >= 0 {
            let blockBefore = blockStorage.blocks[blockBeforeIndex]
            let blockBeforeRect = layoutManager.boundingRect(forBlock: blockBefore)
            let gap = blockBeforeRect.maxY - blockRect.origin.y
            let gapMidpoint = gap / 2

            blockRect.origin.y -= gapMidpoint
            blockRect.size.height += gapMidpoint
        }

        if blockAfterIndex < blockStorage.blocks.count {
            let blockAfter = blockStorage.blocks[blockAfterIndex]
            let blockAfterRect = layoutManager.boundingRect(forBlock: blockAfter)
            let gap = blockAfterRect.origin.y - blockRect.maxY
            let gapMidpoint = gap / 2

            blockRect.size.height += gapMidpoint
        }

        blockRect.origin.y += inset.height

        if location.y < blockRect.midY {
            return (NSRect(x: inset.width, y: blockRect.origin.y - 2, width: width, height: 4), blockIndex)
        } else {
            return (NSRect(x: inset.width, y: blockRect.maxY - 2, width: width, height: 4), blockAfterIndex)
        }
    }

    override func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        super.draggingSession(session, endedAt: screenPoint, operation: operation)
        isInsertionPointHidden = false
    }

    @objc private func blockHoverViewMenuAction(_ menuItem: NSMenuItem) {
        let tag = menuItem.tag

        switch tag {
        case -1:
            deleteSelectedBlocks()

        case -2:
            duplicateSelectedBlocks()

        default:
            if let type = BlocksInfo.Types(rawValue: tag) {
                convertSelectedBlocks(to: type)
            }
        }
    }

    func blockHoverViewContextMenu() -> NSMenu? {
        guard let mouseOverBlock = self.mouseOverBlock else {
            return nil
        }

        func makeMenuItem(withTitle title: String, image: String, tag: Int = Int.max, submenu: NSMenu? = nil) -> NSMenuItem {
            let item = NSMenuItem()
            item.title = title
            item.action = #selector(blockHoverViewMenuAction)
            item.target = self
            item.submenu = submenu
            item.tag = tag
            item.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
            return item
        }

        func makeTurnIntoSubmenuItem(withTitle title: String, tag: BlocksInfo.Types) -> NSMenuItem {
            let item = NSMenuItem()
            item.title = title
            item.tag = tag.rawValue
            item.target = self
            item.action = #selector(blockHoverViewMenuAction)
            return item
        }

        let index = mouseOverBlock.index
        let blockRange: Range<Int>

        if case let .multiBlock(selectedBlockRange) = self.selection, selectedBlockRange.contains(index) {
            blockRange = selectedBlockRange
        } else {
            blockRange = index ..< index + 1
            setSelectedBlocks(blockRange)
        }

        let blocks = blockStorage.blocks[blockRange]

        var items = [
            makeMenuItem(withTitle: "Delete", image: "trash", tag: -1),
            makeMenuItem(withTitle: "Duplicate", image: "doc.on.doc", tag: -2)
        ]

        if blocks.allSatisfy({$0.isConvertable}) {
            items.append(makeMenuItem(withTitle: "Turn Into", image: "repeat", submenu: NSMenu(items: [
                makeTurnIntoSubmenuItem(withTitle: "Text",          tag: .text),
                makeTurnIntoSubmenuItem(withTitle: "Header",        tag: .header1),
                makeTurnIntoSubmenuItem(withTitle: "Subheader",     tag: .header2),
                makeTurnIntoSubmenuItem(withTitle: "List",          tag: .list),
                makeTurnIntoSubmenuItem(withTitle: "Ordered List",  tag: .orderedlist),
                makeTurnIntoSubmenuItem(withTitle: "Code Snippet",  tag: .codesnippet)
            ])))
        }

        if blocks.count == 1 {
            items.append(contentsOf: blocks.first!.contextMenuItems())
        }

        return NSMenu(items: items)
    }

    func duplicateSelectedBlocks() {
        guard case let .multiBlock(selectedBlockRange) = self.selection else {
            NSSound.beep()
            return
        }

        beginEditing()

        if selectedBlockRange.contains(blockStorage.blocks.count - 1) {
            blockStorage.appendTextBlock()
        }

        let insertLocation = selectedBlockRange.upperBound
        let selectedBlocks = blockStorage.blocks[selectedBlockRange]
        let contents = NSMutableAttributedString()
        var copies = [Block]()

        for block in selectedBlocks {
            let (copy, content) = block.copy()
            copies.append(copy)
            contents.append(content)
        }

        blockStorage.insertBlocks(copies, at: insertLocation, contents: contents)
        endEditing()

        setSelectedBlocks(insertLocation ..< insertLocation + selectedBlockRange.count)
    }

    func deleteSelectedBlocks() {
        guard case let .multiBlock(selectedBlockRange) = self.selection else {
            NSSound.beep()
            return
        }

        beginEditing()
        let characterRange = blockStorage.characterRange(forBlockRange: selectedBlockRange)
        blockStorage.deleteBlocks(inRange: selectedBlockRange, withCharacterRange: characterRange)
        endEditing()
    }

    func convertSelectedBlocks(to type: BlocksInfo.Types) {
        guard case let .multiBlock(selectedBlockRange) = self.selection else {
            NSSound.beep()
            return
        }

        let oldBlockCount = blockStorage.blocks.count
        blockStorage.inlineStyling(setBlockType: type, forBlocks: selectedBlockRange)

        let changeInBlockCount = blockStorage.blocks.count - oldBlockCount
        let selectedLowerBound = selectedBlockRange.lowerBound
        let selectedUpperBound = selectedLowerBound + selectedBlockRange.count + changeInBlockCount
        setSelectedBlocks(selectedLowerBound ..< selectedUpperBound)
    }

    func blockHoverViewInsert() {
        if let block = mouseOverBlock {
            beginEditing()
            let inserted = blockStorage.createBlock(at: block.index + 1, ofType: .text)
            endEditing()
            
            setSelectedRange(NSRange(location: inserted.offset, length: 0), in: inserted.index)
        }
    }

    func blockHoverViewDidStartDragging(with event: NSEvent) {
        guard let mouseOverBlock = self.mouseOverBlock,
              let layoutManager = self.layoutManager as? BlockLayoutManager else {
            NSSound.beep()
            return
        }

        let dragRect: NSRect
        let dragRange: NSRange

        if case let .multiBlock(selectedBlockRange) = self.selection,
           selectedBlockRange.contains(mouseOverBlock.index),
           selectedBlockRange.count > 1 {
            let firstBlock = blockStorage.blocks[selectedBlockRange.first!]
            let lastBlock = blockStorage.blocks[selectedBlockRange.last!]
            let topRect = layoutManager.boundingRect(forBlock: firstBlock)
            let bottomRect = layoutManager.boundingRect(forBlock: lastBlock)

            var blocksRect = NSUnionRect(topRect, bottomRect)
            blocksRect.origin.y += textContainerInset.height

            dragRect = blocksRect
            dragRange = blockStorage.characterRange(forBlockRange: selectedBlockRange)
            draggedBlocks = selectedBlockRange
        } else {
            let blockIndex = mouseOverBlock.index
            let inset = textContainerInset

            var rect = layoutManager.boundingRect(forBlock: mouseOverBlock)
            rect.origin.y += inset.height
            rect.origin.x = inset.width
            rect.size.width = frame.size.width - (inset.width * 2)

            dragRect = rect
            dragRange = mouseOverBlock.range
            draggedBlocks = blockIndex ..< blockIndex + 1
        }

        setSelectedRange(NSRange(location: blockStorage.length, length: 0), in: max(blockStorage.blocks.count - 1, 0))
        blockHoverViewController.setHidden(true, animate: false)
        isInsertionPointHidden = true

        let image: NSImage?
        let imageRect: NSRect

        if let opaqueImage = NSImage(data: dataWithPDF(inside: dragRect)) {
            imageRect = NSRect(origin: NSPoint(), size: opaqueImage.size)
            image = NSImage(size: imageRect.size, flipped: false) {rect in
                opaqueImage.draw(at: NSZeroPoint, from: rect, operation: .sourceOver, fraction: 0.5)
                return true
            }
        } else {
            image = nil
            imageRect = NSRect()
        }

        let dragString = blockStorage.mutableString.substring(with: dragRange)
        let draggingItem = NSDraggingItem(pasteboardWriter: dragString as NSString)
        draggingItem.setDraggingFrame(dragRect, contents: image!)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    public override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if sender.draggingSource is TextView {
            return true
        } else {
            return super.prepareForDragOperation(sender)
        }
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let indicator = DraggedBlockDropIndicator(frame: NSRect())
        addSubview(indicator)

        isInsertionPointHidden = true
        dragType = DragType(info: sender)
        draggedBlockDropIndicator = indicator
        mouseOverBlock = nil

        return draggingUpdated(sender)
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        if let indicator = draggedBlockDropIndicator {
            indicator.removeFromSuperview()
            draggedBlockDropIndicator = nil
        }

        super.draggingExited(sender)
    }

    public override func draggingEnded(_ sender: NSDraggingInfo) {
        if let indicator = draggedBlockDropIndicator {
            indicator.removeFromSuperview()
            draggedBlockDropIndicator = nil
        }

        isInsertionPointHidden = false
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard dragType != .default,
              let indicator = draggedBlockDropIndicator,
              let layoutManager = layoutManager as? BlockLayoutManager else {
            return super.draggingUpdated(sender)
        }

        let location = convert(sender.draggingLocation, to: nil)
        let character = characterIndexForInsertion(at: location)
        let block = blockStorage.block(at: character)

        mouseOverBlock = block
        let indicatorPosition = dragIndicatorPosition(draggingAt: location, inBlock: block, layoutManager: layoutManager)
        indicator.frame = indicatorPosition.frame

        if dragType == .block {
            return .private
        } else {
            return .copy
        }
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if dragType == .default {
            return super.performDragOperation(sender)
        }

        guard let layoutManager = self.layoutManager as? BlockLayoutManager else {
            return false
        }

        let location = convert(sender.draggingLocation, to: nil)
        let character = characterIndexForInsertion(at: location)
        let block = blockStorage.block(at: character)
        let position = dragIndicatorPosition(draggingAt: location, inBlock: block, layoutManager: layoutManager)

        switch dragType {
        case .block:
            return performBlockDragOperation(sender, at: position.blockIndex)

        case .image:
            return performImageDragOperation(sender, at: position.blockIndex)

        default:
            fatalError("Unreachable")
        }
    }

    private func performBlockDragOperation(_ sender: NSDraggingInfo, at blockIndex: Int) -> Bool {
        guard let sourceTextView = sender.draggingSource as? TextView,
              let draggedBlockRange = sourceTextView.draggedBlocks else {
            return false
        }

        let sourceBlockStorage = sourceTextView.blockStorage
        var insertLocation = blockIndex

        if sourceTextView === self {
            if insertLocation >= draggedBlockRange.lowerBound && insertLocation <= draggedBlockRange.upperBound  {
                setSelectedBlocks(draggedBlockRange)
                return true
            }

            if insertLocation > draggedBlockRange.lowerBound {
                insertLocation -= draggedBlockRange.count
            }
        } else {
            sourceTextView.breakUndoCoalescing()
        }

        breakUndoCoalescing()
        beginEditing()
        sourceTextView.beginEditing()

        if draggedBlockRange.upperBound == sourceBlockStorage.blocks.count {
            sourceBlockStorage.appendTextBlock()
        }

        if insertLocation == blockStorage.blocks.count - draggedBlockRange.count {
            blockStorage.appendTextBlock()
        }

        let draggedBlocks = [Block](sourceBlockStorage.blocks[draggedBlockRange])
        let draggedCharacterRange = sourceBlockStorage.characterRange(forBlockRange: draggedBlockRange)
        let draggedText = sourceBlockStorage.attributedSubstring(from: draggedCharacterRange)

        sourceBlockStorage.deleteBlocks(inRange: draggedBlockRange, withCharacterRange: draggedCharacterRange)
        blockStorage.insertBlocks(draggedBlocks, at: insertLocation, contents: draggedText)

        sourceTextView.endEditing()
        endEditing()
        breakUndoCoalescing()

        if sourceTextView !== self {
            sourceTextView.breakUndoCoalescing()
        }

        setSelectedBlocks(insertLocation ..< insertLocation + draggedBlockRange.count)
        return true
    }

    private func performImageDragOperation(_ sender: NSDraggingInfo, at blockIndex: Int) -> Bool {
        guard let image = NSImage(pasteboard: sender.draggingPasteboard) else {
            return false
        }

        var characterIndex = 0

        for block in blockStorage.blocks[0 ..< blockIndex] {
            characterIndex += block.length
        }

        beginEditing()
        let range = NSRange(location: characterIndex, length: 0)
        let imageBlock = ImageBlock(owner: blockStorage, range: range, index: blockIndex, image: image)
        blockStorage.insertBlock(imageBlock, at: blockIndex)
        endEditing()
        
        return true
    }

    private func paste(text: String) {
        let selected = selectedRange()
        let inserted = NSRange(location: selected.location, length: text.utf16.count)
        insertText(text, replacementRange: selected)

        if blockStorage.mutableString.compare(text, options: .literal, range: inserted) == .orderedSame {
            let selected = LinkPopupController.SelectedText(text)

            if case .link = selected {
                setSelectedRange(inserted)
                linkPopupController.setSelection(range: inserted, text: selected)
                displayPopup(for: inserted, with: linkPopupController, preferredEdge: .maxY)
                inlineStylingTimerTick += 1
            }
        }
    }

    private func locationForBlockPaste() -> (blockIndex: Int, characterIndex: Int) {
        let blockIndex: Int

        switch selection {
        case .singleBlock(let index, _):
            blockIndex = index + 1

        case .multiBlock(let blockRange):
            blockIndex = blockRange.upperBound

        case .none:
            blockIndex = blockStorage.blockRange(for: selectedRange()).upperBound
        }

        let characterIndex = blockStorage.blocks[blockIndex - 1].range.upperBound
        return (blockIndex, characterIndex)
    }

    private func paste(image: NSImage) {
        beginEditing()
        let (blockIndex, characterIndex) = locationForBlockPaste()
        let range = NSRange(location: characterIndex, length: 0)
        let imageBlock = ImageBlock(owner: blockStorage, range: range, index: blockIndex, image: image)
        blockStorage.insertBlock(imageBlock, at: blockIndex)
        endEditing()

        setSelectedBlocks(blockIndex ..< blockIndex + 1)
    }

    private func paste(blocks blockData: Data) {
        guard let codedBlocks = try? JSONDecoder().decode([CodedBlock].self, from: blockData) else {
            NSSound.beep()
            return
        }

        breakUndoCoalescing()
        beginEditing()

        let (blockIndex, characterIndex) = locationForBlockPaste()
        let blockRange = blockStorage.createBlocks(from: codedBlocks, characterOffset: characterIndex, blockIndex: blockIndex)

        endEditing()

        if blockRange.isEmpty {
            NSSound.beep()
        } else {
            setSelectedBlocks(blockRange)
        }
    }

    private func checkLinks(forPasteAt pasteLocation: Int, lengthBeforePaste oldLength: Int) {
        let string = blockStorage.mutableString
        var insertedRange = NSRange(location: pasteLocation, length: blockStorage.length - oldLength)
        let newlineCharacter = string.rangeOfCharacter(from: .newlines, options: [], range: insertedRange)

        if newlineCharacter.length != 0 {
            if newlineCharacter.location == (insertedRange.upperBound - 1) {
                insertedRange.length -= 1
            } else {
                return
            }
        }

        let inserted = string.substring(with: insertedRange)
        let selected = LinkPopupController.SelectedText(inserted)

        if case .link = selected {
            setSelectedRange(insertedRange)
            linkPopupController.setSelection(range: insertedRange, text: selected)
            displayPopup(for: insertedRange, with: linkPopupController, preferredEdge: .maxY)
            inlineStylingTimerTick += 1
        }
    }

    private func paste(attributedString: NSAttributedString) {
        let length = blockStorage.length
        let selected = selectedRange()
        let block = blockStorage.block(at: selected.location)

        if block.isSingleLine == false {
            blockStorage.replaceCharactersWithUndo(in: selected, with: attributedString)
            checkLinks(forPasteAt: selected.location, lengthBeforePaste: length)
            return
        }

        let string = attributedString.string as NSString
        let lineRanges = string.lineRanges()

        if block.isEmpty {
            let blockIndex = block.index
            let lines = lineRanges.map({attributedString.attributedSubstring(from: $0)})

            beginEditing()
            blockStorage.createBlocks(at: blockIndex + 1, withLines: lines)
            blockStorage.deleteBlocks(inRange: blockIndex ..< blockIndex + 1, withCharacterRange: block.range)
            endEditing()
        } else if lineRanges.count <= 1 {
            blockStorage.replaceCharactersWithUndo(in: selected, with: attributedString)
        } else {
            let blockIndex = block.index
            let firstLine = attributedString.attributedSubstring(from: lineRanges[0])
            let otherLines = lineRanges.dropFirst().map({attributedString.attributedSubstring(from: $0)})

            blockStorage.replaceCharactersWithUndo(in: selected, with: firstLine)

            beginEditing()
            blockStorage.createBlocks(at: blockIndex + 1, withLines: otherLines)
            endEditing()
        }

        if lineRanges.count <= 1 {
            checkLinks(forPasteAt: selected.location, lengthBeforePaste: length)
        }
    }

    private func paste(markdown: String) {
        let length = blockStorage.length
        let selected = selectedRange()
        let block = blockStorage.block(at: selected.location)

        if block.isSingleLine == false {
            let attributedString = attributedStringWithInlineStyles(fromMarkdown: markdown)
            blockStorage.replaceCharactersWithUndo(in: selected, with: attributedString)
            checkLinks(forPasteAt: selected.location, lengthBeforePaste: length)
            return
        }

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)

        if block.isEmpty {
            let blockIndex = block.index

            beginEditing()
            blockStorage.createBlocks(at: blockIndex + 1, withMarkdown: lines.map({String($0)}))
            blockStorage.deleteBlocks(inRange: blockIndex ..< blockIndex + 1, withCharacterRange: block.range)
            endEditing()
        } else if lines.count <= 1 {
            let attributedString = attributedStringWithInlineStyles(fromMarkdown: markdown)
            blockStorage.replaceCharactersWithUndo(in: selected, with: attributedString)
        } else {
            let blockIndex = block.index
            let firstLine = attributedStringWithInlineStyles(fromMarkdown: String(lines[0]))

            blockStorage.replaceCharactersWithUndo(in: selected, with: firstLine)

            beginEditing()
            blockStorage.createBlocks(at: blockIndex + 1, withMarkdown: lines.dropFirst().map({String($0)}))
            endEditing()
        }

        if lines.count <= 1 {
            checkLinks(forPasteAt: selected.location, lengthBeforePaste: length)
        }
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        if let blockData = pasteboard.data(forType: NSPasteboard.PasteboardType(rawValue: "text.block")) {
            paste(blocks: blockData)
        } else if let rtf = pasteboard.data(forType: .rtf), let string = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            paste(attributedString: string)
        } else if let image = NSImage(pasteboard: pasteboard) {
            paste(image: image)
        } else if let html = pasteboard.data(forType: .html), let string = NSAttributedString(html: html, documentAttributes: nil)  {
            paste(attributedString: string)
        } else if let text = pasteboard.string(forType: .string) {
            paste(markdown: text)
        }
    }

    private func copy(blocks blockRange: Range<Int>) {
        let attributedString = blockStorage.attributedSubstring(fromBlockRange: blockRange)
        let pasteboard = NSPasteboard.general
        
        pasteboard.clearContents()
        pasteboard.writeObjects([attributedString])

        var codedBlocks = [CodedBlock]()

        for block in blockStorage.blocks[blockRange] {
            if let coded = try? CodedBlock(block) {
                codedBlocks.append(coded)
            }
        }

        if codedBlocks.isEmpty == false, let json = try? JSONEncoder().encode(codedBlocks) {
            pasteboard.setData(json, forType: NSPasteboard.PasteboardType(rawValue: "text.block"))
        } else {
            NSSound.beep()
        }
    }

    override func copy(_ sender: Any?) {
        if case let .multiBlock(blockRange) = selection {
            copy(blocks: blockRange)
        } else {
            super.copy(sender)
        }
    }
}
