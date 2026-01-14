import Cocoa
import UniformTypeIdentifiers

extension NSString {
    /// Split the NSString into an array of ranges of the individual lines. I.e. split at linebreak character.
    /// - Returns: Array of ranges for individual lines
    func lineRanges() -> [NSRange] {
        let fullRange = NSRange(location: 0, length: length)
        var ranges: [NSRange] = []

        // Enumerate the full NSString divided into lines (separated by linebreak). Then append the ranges to the array.
        // .subStringNotRequired is a performance boost when you don't need the substring passed into the closure.
        enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired], using: {_, range, _, _ in
            ranges.append(range)
        })

        return ranges
    }
}

/// Check if pasteboard contains image
fileprivate func pasteboardContainsImage(_ pasteboard: NSPasteboard) -> Bool {
    guard let types = pasteboard.types else {
        return false
    }

    let imageTypes: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType(UTType.jpeg.description),
        .png,
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

/// Get UTType of URL
///
/// Method is only used in ``pasteboardContainsImage(_:)``
fileprivate func typeIndentifier(for url: URL) -> UTType? {
    if let resources = try? url.resourceValues(forKeys: [.typeIdentifierKey]),
       let typeIdentifier = resources.typeIdentifier {
        return UTType(typeIdentifier)
    } else {
        return UTType(filenameExtension: url.pathExtension)
    }
}


/// The type of content being dragged (whether it's a block internally in this app or e.g. an image file getting dragged into the view)
enum DragType {
    case `default` // external drag, non image
    case block     // internal drag, any block
    case image     // external drag, image

    init(info: NSDraggingInfo) {
        if info.draggingSource is TextView
        {
            self = .block
        }
        else if pasteboardContainsImage(info.draggingPasteboard)
        {
            self = .image
        }
        else
        {
            self = .default
        }
    }
 }

/// The type of text selection and necessary related information
enum TextSelection {
    case none
    case multiBlock(Range<Int>)
    case singleBlock(Int, NSRange)

    var isMultiBlock: Bool {
        switch self
        {
        case .multiBlock(_):
            return true
        default:
            return false
        }
    }

    var isSingleBlock: Bool {
        switch self
        {
        case .singleBlock(_, _):
            return true
        default:
            return false
        }
    }

    func selectedBlocks() -> Range<Int> {
        switch self
        {
        case .multiBlock(let range):
            return range

        case .singleBlock(let blockIndex, _):
            return blockIndex ..< blockIndex

        case .none:
            return -1 ..< -1
        }
    }
}

let DEBUGGING_MODE = true

class TextView: NSTextView, NSTextViewDelegate, BlockHoverViewDelegate {
	// MARK: Properties
    
    /// Responsible for NSTextStorage and block storage
    var blockStorage: TextBlockStorage
    
    /// Delegate responsible for sending info to SwiftUI bindings
    public var containerDelegate: TextViewContainerDelegate!

    /// Note: Using an internal UndoManager like this will cause problems if we want to share the undo stack with other UI elements. If that use case arises, push this up to the NSWindow level and pass down a reference.
    private var blockUndoManager: BlockUndoManager
    
    /// The type of text edit is determined in shouldChangeText and the relevant information is stored cleanly in this property for easy access in other parts.
    private var lastEdit: (block: Block, edit: BlockEdit)? = nil
    private(set) public var editCount: Int = 0

    /// Basically mainly a property used in a mechanism to prevent the following: You copy in a link, the link popup controller appears after a small delay, but then copying in the
    /// link causes text selection which triggers the inline styling popup controller to appear, removing the link popup controller. There is probably a better way to handle this though.
    private var inlineStylingTimerTick = 0
    
    private var popoverManager: PopoverManager!
    
    /// See: BlockHoverViewController
    private var blockHoverViewController: BlockHoverViewController!
    /// See: BlockMenuViewController
    private var blockMenuViewController = BlockMenuViewController()
    
    /// Whether text view is scrollable
    var isScrollable: Bool = true

    /// Encapsulate temporary event state in struct
    struct DragState {
        /// isMouseDown
        var isMouseDown = false
        /// isDragging
        var isDragging = false

        var mouseEventTick = 0
        /// This is true when a drag event should be multiblock, not selecting text within a block. I.e. when the transparent blue rectangle should appear (DragSelectIndicatorView)
        var dragForceMultiblock = false
        /// The point where a drag operation began
        var dragOriginPoint = NSPoint()
        /// The index of the character where the drag operation began
        var dragOriginCharacterIndex = 0
        /// The block where the drag operation began
        var dragOriginBlock: Block! = nil
        /// The range of (the text within) the block where the drag operation began (dragOriginBlock)
        var dragOriginBlockRange = NSRange()
        /// The bounding rect of the block where the drag operation began (dragOriginBlock)
        var dragOriginBlockRect = NSRect()
        /// The textRect from which the drag operation began. textRect is the entire region that contains text.
        var dragTextRect = NSRect()
        /// Transparent light blue rectangle indicating multi block selection
        var dragSelectIndicator: DragSelectIndicatorView? = nil
        /// Type of drag, mainly based on the content being dragged
        var dragType: DragType = .default
        
        /// The block that the mouse is currently hovering over
        var mouseOverBlock: Block? = nil
        /// The rect surrounding mouseOverBlock
        var mouseOverBlockRect: NSRect? = nil

        /// Blue line drop indicator where block will be placed if mousedown is released
        var draggedBlockDropIndicator: DraggedBlockDropIndicator? = nil
        /// The range of blocks being dragged in case of a multi block drag
        var draggedBlocks: Range<Int>? = nil
        
        /// Get the range starting from the character where the dragging started to the character at the current mouse position
        /// - Parameter characterIndex: character index of current mouse position
        /// - Returns: range
        func getMouseDraggedOverRange(to characterIndex: Int) -> (NSRange, NSSelectionAffinity) {
            if characterIndex > dragOriginCharacterIndex
            {
                let range = NSRange(location: dragOriginCharacterIndex, length: characterIndex - dragOriginCharacterIndex)
                return (range, .upstream)
            }
            else
            {
                let range = NSRange(location: characterIndex, length: dragOriginCharacterIndex - characterIndex)
                return (range, .downstream)
            }
        }
        
        /// Check if the mouse is still hovering over the same block that it was at the previous moment in time
        ///  - Parameter point: current mouse position
        func mouseRemainsOverSameBlock(point: NSPoint) -> Bool {
            if let oldMouseRect = mouseOverBlockRect {
                return point.y >= oldMouseRect.origin.y && point.y <= oldMouseRect.maxY
            }
            
            return false
        }
    }
    
    private var dragState = DragState()

    /// Type of current text selection (single/multi block, etc.) with related information
    public var selection: TextSelection = .none
    
//    func setTextContainerInset(_ inset: NSSize) {
//        self.textContainerInset = inset
//        blockHoverViewController.addSubview(textContainerInset: inset)
//    }
    
    // MARK: Insertion Point
    
//    struct InsertionPoint {
//        private var actualColor: NSColor = NSColor.black
//        var isHidden: Bool = false
//        var rect = NSRect(x: 0, y: 0, width: 0, height: 0)
//        var color: NSColor {
//            get {
//                isHidden ? NSColor.clear : actualColor
//            }
//            set {
//                actualColor = newValue
//            }
//        }
//    }
    
    private struct InsertionPoint {
        var isHidden: Bool = false
        var rect = NSRect(x: 0, y: 0, width: 0, height: 0)
        var color: NSColor = NSColor.Primary.Regular
    }
    
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        super.drawInsertionPoint(in: rect, color: insertionPoint.color, turnedOn: flag)
        insertionPoint.rect = rect
    }
    
    private var insertionPoint = InsertionPoint()

	// MARK: Initialization
    
    init(frame: NSRect, inset: NSSize) {
        // Block Undo Manager
        blockUndoManager = BlockUndoManager()

        // Layout Manager
        let layoutManager = BlockLayoutManager()
            layoutManager.allowsNonContiguousLayout = true
        
        // Block Storage
        blockStorage = TextBlockStorage()
        blockStorage.addLayoutManager(layoutManager)

        // Text Container
        let textContainer = NSTextContainer(containerSize: frame.size)
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(
            width: frame.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        
        // Connect layout manager to text container and block storage
        layoutManager.addTextContainer(textContainer)
        layoutManager.delegate = blockStorage

        blockMenuViewController.delegate = blockStorage
        
        super.init(frame: frame, textContainer: textContainer)
        textContainerInset = inset
        
        self.font = NSFont.systemFont(ofSize: TextBlock.fontSize)
        self.delegate = self

        blockStorage.textView = self
        
        blockHoverViewController = BlockHoverViewController(inset: inset)
        blockHoverViewController.delegate = self
        addSubview(blockHoverViewController.view)
        
        popoverManager = PopoverManager(textView: self)

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(willUndoOrRedoChange(_:)), name: .NSUndoManagerWillUndoChange, object: blockUndoManager)
        notificationCenter.addObserver(self, selector: #selector(willUndoOrRedoChange(_:)), name: .NSUndoManagerWillRedoChange, object: blockUndoManager)
        notificationCenter.addObserver(self, selector: #selector(didUndoOrRedoChange(_:)), name: .NSUndoManagerDidUndoChange, object: blockUndoManager)
        notificationCenter.addObserver(self, selector: #selector(didUndoOrRedoChange(_:)), name: .NSUndoManagerDidRedoChange, object: blockUndoManager)
        notificationCenter.addObserver(self, selector: #selector(didReachUndoManagerCheckpoint(_:)), name: .NSUndoManagerCheckpoint, object: blockUndoManager)
        
        self.becomeFirstResponder()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// A method that is called after actual initialization (init) and some additional setup stuff
    func initialize() {
        // Get the contents of this chapter saved in the database and paste it in
        guard let contents = containerDelegate.loadContents() else { return }
        paste(contents: contents)
    }
    
    /// Event associated with .NSUndoManagerWillUndoChange and .NSUndoManagerWillRedoChange
    @objc func willUndoOrRedoChange(_: Notification) {
        editCount += 1
    }

    @objc func didUndoOrRedoChange(_ : Notification) {
        editCount -= 1
        blockStorage.layoutDeferred()
    }
    
    /// This method runs at every checkpoint of the undo manager. I.e. every time user adds new block, removes block, etc. The document is saved each time this method runs.
    /// TODO: The undo manager is currently not granular enough. Make it have checkpoints more often. I.e. every one or two words typed.
    /// - Parameter _: <#_ description#>
    @objc func didReachUndoManagerCheckpoint(_: Notification) {
//        saveProgress()
    }

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func menu(for event: NSEvent) -> NSMenu? {
		let menu = NSMenu()
            menu.addItem(withTitle: "Start Speaking", action: #selector(startSpeaking(_:)), keyEquivalent: "")
		return menu
	}
    
    /// Event which runs every time a key is pressed
    /// - Parameter event: Event information (which key was clicked, modifiers, etc.)
    override func keyDown(with event: NSEvent) {
        if isEditable == false {
            return
        }
        
        // Only proceed if user is holding down command key
        guard event.modifierFlags.contains(.command) else {
            return super.keyDown(with: event)
        }
        
        if let style = StyleBuilder.InlineStyles.init(from: event)
        {
            // Apply inline styling when user types command + B/I/etc.
            if case .singleBlock(_, _) = self.selection
            {
                blockStorage.inlineStyling(toggleStyle: style, forCharacters: selectedRange(), inBlockRange: selectedBlocks())
            }
        }
        
        if event.keyCode == Keycode.s
        {
            saveChapterContents()
        }
        
        if event.keyCode == Keycode.f
        {
            blockStorage.printBlocks()
        }
        
        super.keyDown(with: event)
    }
    
    private var stringAtPreviousSave: String = ""
    
    /// Save state of textview to file
    func saveChapterContents(async: Bool = true) {
        guard let currentString = textStorage?.string, currentString != stringAtPreviousSave else {
            return
        }
        
        stringAtPreviousSave = currentString
        
        DispatchQueue.main.async { [weak self] in
            if let contents = try? self?.blockStorage.getCodedContents()
            {
                let _ = self?.containerDelegate.saveContents(contents: contents)
            }
        }
    }
    
    /// Display inline styling popup - i.e. the menu that appears above some selected text with option to apply inline styling and change block type
    private func displayInlineStylingPopup() {
        popoverManager.displayInlineStylingPopup(selection: selection)
    }
    
    /// Request to open a link popup controller. Pass the information from current selection to the link popup controller. Display it via a method responsible
    /// for correct placement etc.
    /// - Parameters:
    ///   - range: range of current selection
    ///   - text: text in current selection
    ///   - url: url of the selected link, if any
    public func displayLinkPopup(for range: NSRange, text: String, url: URL? = nil) {
        popoverManager.displayLinkPopup(for: range, text: text, url: url)
    }
    
    /// Runs when the text view changes selection
    public func textViewDidChangeSelection(_ notification: Notification) {
        if editCount == 0 {
            updateTypingAttributes()
        }
        
        // Inform the popover manager about selection change, so it can hide the active popover.
        popoverManager.textViewDidChangeSelection(selection: selection)
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
    
    // MARK: Deferred Commands
    private var deferredCommandQueue: [TextViewCommand] = []
    
    func executeDeferredCommands() {
        for command in deferredCommandQueue
        {
            if command.shouldExecute() && editCount == 0
            {
                command.execute(textView: self)
                deferredCommandQueue.removeFirst()
            }
            else
            {
                break
            }
        }
    }
    
    func addDeferredCommand(_ command: TextViewCommand) {
        deferredCommandQueue.append(command)
    }

    // MARK: Editing text
    
    enum PerformEditOptions {
        case beginAndEndEditing
        case breakUndoCoalescing
    }
    
    @discardableResult func performEditCharacters(in range: NSRange, replacement: String, with options: [PerformEditOptions] = []) -> Bool {
        if options.contains(.breakUndoCoalescing) {
            breakUndoCoalescing()
        }
        
        if options.contains(.beginAndEndEditing) {
            beginEditing()
        }
        
        if shouldChangeText(in: range, replacementString: replacement) == false {
            if options.contains(.beginAndEndEditing) {
                endEditing()
            }
            return false
        }
        
        blockStorage.replaceCharacters(in: range, with: replacement)
        blockStorage.edited([.editedCharacters], range: range, changeInLength: replacement.count - range.length)
        didChangeText()
        
        if options.contains(.beginAndEndEditing) {
            endEditing()
        }
        
        return true
    }
    
    // MAYBE COMPLETE LATER, see Block.swift(69)
//    @discardableResult func performEditCharactersWithAttributes(in range: NSRange, replacement: NSAttributedString, with options: [PerformEditOptions] = []) -> Bool {
//        if options.contains(.breakUndoCoalescing) {
//            breakUndoCoalescing()
//        }
//
//        if options.contains(.beginAndEndEditing) {
//            beginEditing()
//        }
//
//        if shouldChangeText(in: range, replacementString: replacement.string) == false {
//            if options.contains(.beginAndEndEditing) {
//                endEditing()
//            }
//            return false
//        }
//
//        blockStorage.insert(replacement, at: range.location)
//        blockStorage.replaceCharacters(in: range, with: replacement)
//        blockStorage.edited([.editedCharacters], range: range, changeInLength: replacement.count - range.length)
//        didChangeText()
//
//        if options.contains(.beginAndEndEditing) {
//            endEditing()
//        }
//
//        return true
//    }
    
    @discardableResult func performEditAttributes(in range: NSRange, with options: [PerformEditOptions] = [], _ edit: () -> Void) -> Bool {
        if options.contains(.breakUndoCoalescing) {
            breakUndoCoalescing()
        }
        
        if options.contains(.beginAndEndEditing) {
            beginEditing()
        }
        
        if shouldChangeText(in: range, replacementString: nil) == false {
            if options.contains(.beginAndEndEditing) {
                endEditing()
            }
            return false
        }
        
        edit()
        
        blockStorage.edited([.editedAttributes], range: range, changeInLength: 0)
        
        didChangeText()
        
        if options.contains(.beginAndEndEditing) {
            endEditing()
        }
        
        return true
    }
    
    /// When the user types "/" at the beginning of a line, open up a menu to select the block type. This method handles that behavior.
    /// - Parameters:
    ///   - location: The location (starting point) of the range of text that is being edited
    ///   - block: The block that is being edited
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
    }

    @discardableResult override func shouldChangeText(in replacementRange: NSRange, replacementString: String?) -> Bool {
        editCount += 1
        
        guard editCount == 1, let string = replacementString else {
            return super.shouldChangeText(in: replacementRange, replacementString: string)
        }
        
        let edit: BlockEdit
        let block = blockStorage.block(at: replacementRange.location)
        let blockRange = block.range
        let blockEnd = blockRange.upperBound
        let replacementRangeEnd = replacementRange.upperBound

        // Determine the type of edit that is being performed, and store it in the BlockEdit enum
        if replacementRangeEnd > blockEnd
        {
            edit = .multiBlockEdit(replacementRange, string)
        }
        else if replacementRangeEnd == blockEnd && string.isEmpty && replacementRange.length == 1
        {
            edit = .deleteLastCharacter(replacementRange)
        }
        else if let firstNewline = string.firstIndex(where: {$0.isNewline})
        {
            edit = .replaceWithLines(replacementRange, string, firstNewline)
        }
        else if replacementRange.length != 0
        {
            edit = .replace(replacementRange, string)
        }
        else
        {
            edit = .insert(replacementRange, string)
        }

        lastEdit = (block, edit)
        block.willEdit(edit)
        
//        containerDelegate.textChanged()

        return super.shouldChangeText(in: replacementRange, replacementString: string)
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

        lastEdit = nil
        
        executeDeferredCommands()
        
        super.didChangeText()

        if blockMenuViewController.isOpen
        {
            blockMenuViewController.didEdit(block: block, edit: edit)
        }
        // If edit is of type insertion and the character inserted is "/", open the block selection menu
        else if case let .insert(range, string) = edit, string == "/" {
            handleInsertedSlash(at: range.location, in: block)
        }

        updateTypingAttributes()
        
        smartScroll()
    }
    
    /// If the insertion point is outside of the portion of the text view that is visible within the scroll view, automatically scroll to where it is visible.
    func smartScroll() {
        if visibleRect.contains(insertionPoint.rect) {
            return
        }
        
        scrollToVisible(insertionPoint.rect)
    }
    
    private func updateTypingAttributes() {
        switch selection
        {
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

            if range.location == blockStorage.length
            {
                if let block = blockStorage.blocks.last, block.length == 0
                {
                    typingAttributes = block.style.attributes
                }
            }
            else if blockStorage.mutableString.compare("\n", options: .literal, range: NSRange(location: range.location, length: 1)) == .orderedSame
            {
                let block = blockStorage.block(at: range.location)

                if block.length == 1 {
                    typingAttributes = block.style.attributes
                }
            }
        }
    }

    // MARK: Override specific input events
    
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
    
    // MARK: ------------------------------------------
    
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

            let prevBlock = blockStorage.block(atIndex: blockIndex)
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

        let block = blockStorage.block(atIndex: blockIndex)
        
        // Get selected range and block index differently depending on whether it's forward or backwards selection,
        // and calling a method that can be overwritten by special block types (e.g. list)
        let adjusted: (index: Int, range: NSRange)
        if range.location < selectedRange().location {
            adjusted = adjustSelectionBackward(range, startingWith: block)
        } else {
            adjusted = adjustSelectionForward(range, startingWith: block)
        }

        // Set selection (internally for tracking and actually set it via textview)
        selection = .singleBlock(adjusted.index, adjusted.range)
        super.setSelectedRanges([NSValue(range: adjusted.range)], affinity: affinity, stillSelecting: stillSelecting)

        if block.length <= 1 {
            typingAttributes = block.style.attributes
        }
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        assert(ranges.count <= 1, "Support for multiple selections not implemented")

        if ranges.isEmpty == false && editCount == 0
        {
            let range = ranges[0].rangeValue

            // If selected range is empty, i.e. just the cursor..
            if range.length == 0
            {
                // ..get the block at that character index and proceed
                let block = blockStorage.block(at: range.location)
                return setSelectedRange(range, in: block.index, affinity: affinity, stillSelecting: stillSelecting)
            }

            // If selected range is non empty and within a single block..
            if case let .singleBlock(blockIndex, _) = selection
            {
                // ..get the block index from the active selection and proceed
                return setSelectedRange(range, in: blockIndex, affinity: affinity, stillSelecting: stillSelecting)
            }
        }

        // If selection is multi block, cancel it and redraw the view. setSelectedRanges is not called while a
        // multiblock selection is happening. It uses a different thing.
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
            converted = convert(point, to: self)
        }

        for view in subviews {
            if let hit = view.hitTest(converted) {
                return hit
            }
        }

        return self
    }
    
    // MARK: Mouse events
    
    /// The NSResponder for the SwiftUI container that hosts this text view. Sometimes necessary to send events there.
    /// current view -> NSClipView -> NSScrollView -> SwiftUIPlatformViewHost
    var containerResponder: NSResponder? {
        nextResponder?.nextResponder?.nextResponder?.nextResponder
    }
    
    /// User scroll event (scrolling mouse or trackpad)
    override func scrollWheel(with event: NSEvent) {
        if isScrollable
        {
            // I believe this is roughly equivalent (but preferable) to writing e.g. super.scrollWheel(with: event)
            nextResponder?.scrollWheel(with: event)
        }
        else
        {
            // If textview is not scrollable, pass event up to the view that should handle it.
            containerResponder?.scrollWheel(with: event)
        }
    }
    
    /// Input absolute NSPoint and return NSPoint relative to this NSTextView, either with or without adjusting for insets
    /// - Parameter point: NSPoint
    /// - Returns: Tuple of 1) normal NSView converted and 2) converted + adjusted for insert
    private func getAdjustedPoint(point: NSPoint) -> (NSPoint, NSPoint) {
        let convertedPoint = self.convert(point, from: nil)
        let insetAdjustedPoint = NSPoint(x: convertedPoint.x - textContainerInset.width, y: convertedPoint.y - textContainerInset.height)

        return (convertedPoint, insetAdjustedPoint)
    }
    
    /// Mouse down event
    override func mouseDown(with event: NSEvent) {
        // If textview isn't editable, pass mouseDown event up to the view that should handle it.
        guard isEditable else {
            containerResponder?.mouseDown(with: event)
            return
        }
        
        // Update drag state
        dragState.mouseEventTick += 1
        dragState.isMouseDown = true
        
        // Hide block menu view controller
        blockMenuViewController.dismiss()
        
        // Get the character index and block where the mouse down happened
        let (point, _) = getAdjustedPoint(point: event.locationInWindow)
        let characterIndex = characterIndexForInsertion(at: point)
        let block = blockStorage.block(at: characterIndex)

        var blockRect = (layoutManager as? BlockLayoutManager)?.getBoundingRect(forBlock: block) ?? NSRect()
            blockRect.origin.y += textContainerInset.height
            blockRect.size.width = frame.size.width

        setSelectedRange(NSRange(location: characterIndex, length: 0), in: block.index)

        dragState.dragTextRect = textRect()
        dragState.dragOriginPoint = point
        dragState.dragOriginBlock = block
        dragState.dragOriginCharacterIndex = characterIndex
        dragState.dragOriginBlockRange = block.range
        dragState.dragOriginBlockRect = blockRect
        dragState.dragForceMultiblock = dragState.dragTextRect.contains(point) == false || block.isTextSelectable == false
    }

    /// Handles mouse dragging behavior when dragging occurs within a block, i.e. normal text selection
    private func mouseDragged(inSingleBlockTo point: NSPoint, atCharacterIndex characterIndex: Int) {
        guard isEditable else {
            return
        }
        
        if let indicator = dragState.dragSelectIndicator {
            indicator.isHidden = true
        }

        let (range, affinity) = dragState.getMouseDraggedOverRange(to: characterIndex)
        
        setSelectedRange(range, in: dragState.dragOriginBlock.index, affinity: affinity)
    }
    
    /// Handles mouse dragging behavior when dragging occurs across blocks, i.e. while in multi block selection mode, i.e. when the transparent blue rectangle is shown.
    /// - Parameters:
    ///   - point: current mouse position
    ///   - characterIndex: index of character located at current mouse position
    private func mouseDragged(inMultipleBlocksTo point: NSPoint, atCharacterIndex characterIndex: Int) {
        // The frame of the transparent selection rectangle
        let indicatorFrame = NSRect(x: min(dragState.dragOriginPoint.x, point.x),
                                    y: min(dragState.dragOriginPoint.y, point.y),
                                    width: abs(dragState.dragOriginPoint.x - point.x),
                                    height: abs(dragState.dragOriginPoint.y - point.y))

        let dragOriginBlockIndex = dragState.dragOriginBlock.index
        
        // If indicator frame intersects rectangle containing all blocks
        if indicatorFrame.intersects(dragState.dragTextRect)
        {
            let blockAtPoint = blockStorage.block(at: characterIndex)
            /// The range (of text) starting from the beginning of dragOriginBlockRange to the end of blockAtPoint.
            /// (Or vice versa if selecting in an upwards fashion). Basically the text range across blocks of current multi
            /// block selection.
            let range = NSUnionRange(blockAtPoint.range, dragState.dragOriginBlockRange)
            let blockAtPointIndex = blockAtPoint.index

            /// Set selected blocks differently depending on whether selection is happening in an upwards or downwards
            /// fashion.
            if blockAtPointIndex < dragOriginBlockIndex
            {
                let blockRange = blockAtPointIndex ..< (dragOriginBlockIndex + 1)
                setSelectedBlocks(blockRange, range: range, affinty: .upstream, stillSelecting: true)
            }
            else
            {
                let blockRange = dragOriginBlockIndex ..< (blockAtPointIndex + 1)
                setSelectedBlocks(blockRange, range: range, affinty: .downstream, stillSelecting: true)
            }
        }
        else
        {
            let range = NSRange(location: dragState.dragOriginCharacterIndex, length: 0)
            setSelectedRange(range, in: dragOriginBlockIndex, affinity: .downstream, stillSelecting: true)
        }

        if let indicator = dragState.dragSelectIndicator
        {
            indicator.frame = indicatorFrame
            indicator.isHidden = false
        }
        else
        {
            let indicatorView = DragSelectIndicatorView(frame: indicatorFrame)
            dragState.dragSelectIndicator = indicatorView
            addSubview(indicatorView)
//            insertionPoint.isHidden = true
        }
    }

    /// Mouse dragged event
    override func mouseDragged(with event: NSEvent) {
        guard isEditable else {
            containerResponder?.mouseDragged(with: event)
            return
        }
        
        guard dragState.isMouseDown else {
            return
        }

        let (point, _) = getAdjustedPoint(point: event.locationInWindow)
        dragState.mouseEventTick += 1

        // Mouse drag events are pretty sensitive. Wait until the mouse has moved some threshold value away
        // from the original mouse down point before we start dragging.
        if dragState.isDragging == false {
            if point.distance(from: dragState.dragOriginPoint) < 2 {
                return
            }

            dragState.isDragging = true
        }

        let characterIndex = characterIndexForInsertion(at: point)

        if dragState.dragForceMultiblock || dragState.dragOriginBlockRect.contains(point) == false
        {
            mouseDragged(inMultipleBlocksTo: point, atCharacterIndex: characterIndex)
        }
        else
        {
            mouseDragged(inSingleBlockTo: point, atCharacterIndex: characterIndex)
        }

        if visibleRect.contains(point) == false && autoscroll(with: event)
        {
            let currentTick = dragState.mouseEventTick

            // We need to call autoscroll() repeatedly here, but mouseDragged events only fire when the mouse has
            // moved, so we use a timer here to continue autoscrolling even when the mouse is stationary.
            DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(12))) {
                if self.dragState.mouseEventTick == currentTick
                {
                    self.mouseDragged(with: event)
                }
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        // If textview isn't editable, pass mouseUp event up to the view that should handle it.
        guard isEditable else {
            containerResponder?.mouseUp(with: event)
            return
        }
        
        dragState.mouseEventTick += 1
        dragState.isMouseDown = false

        if let indicator = dragState.dragSelectIndicator
        {
            indicator.removeFromSuperview()
            dragState.dragSelectIndicator = nil
//            insertionPoint.isHidden = false
            updateInsertionPointStateAndRestartTimer(true)
        }

        if dragState.isDragging
        {
            dragState.isDragging = false
            super.setSelectedRanges([NSValue(range: selectedRange())], affinity: selectionAffinity, stillSelecting: false)
        }
        else if event.clickCount == 1
        {
            let attrs = blockStorage.attributes(at: dragState.dragOriginCharacterIndex, effectiveRange: nil)
            
            if let url = attrs[.link] as? URL
            {
                NSWorkspace.shared.open(url)
            }
        }
        else if event.clickCount == 2
        {
            selectWord(forCharacter: dragState.dragOriginCharacterIndex, inBlock: dragState.dragOriginBlock)
        }
        else if dragState.dragOriginCharacterIndex < blockStorage.length
        {
            let attributes = blockStorage.attributes(at: dragState.dragOriginCharacterIndex, effectiveRange: nil)

            if let link = attributes[.link] as? URL
            {
                if NSWorkspace.shared.open(link) == false
                {
                    NSSound.beep()
                }
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if isEditable == false {
            containerResponder?.mouseExited(with: event)
            return
        }
        
        blockHoverViewController.setHidden(true)
    }
    
    private var lastBlockRectLen = 0
    
    /// Run when mouse moves (used to capture hover events)
    /// Events that are checked: Block Hover View Controller appear/disappear
    /// - Parameter event: <#event description#>
    override func mouseMoved(with event: NSEvent) {
        // If textview isn't editable, pass mouseMoved event up to the view that should handle it.
        guard isEditable else {
            containerResponder?.mouseMoved(with: event)
            return
        }
        
        guard let layoutManager = self.layoutManager as? BlockLayoutManager else {
            return
        }
        
        // Get proper point
        let (point, _) = getAdjustedPoint(point: event.locationInWindow)
        
        // Show pointing hand if hovering over page link
        let character = characterIndexForInsertion(at: point)
        let attrs = blockStorage.attributes(at: character, effectiveRange: nil)
        
        if attrs.keys.contains(.link)
        {
            NSCursor.pointingHand.set()
        }
//        else
//        {
//            super.mouseMoved(with: event)
//        }
//        else if dragState.mouseOverBlock != nil
//        {
//            NSCursor.iBeam.set()
//        }
//        else
//        {
//            NSCursor.arrow.set()
//        }
        
        // If mouse remains over same point, return
        if dragState.mouseRemainsOverSameBlock(point: point)
        {
            blockHoverViewController.setHidden(false)
            return
        }

        // Remove or change location of block hover view
        let block = blockStorage.block(at: character)
        let inset = textContainerInset
        
        var blockRect = layoutManager.getBoundingRect(forBlock: block)
            blockRect.origin.y += inset.height
            blockRect.origin.x = inset.width

        if point.y >= blockRect.origin.y && point.y <= blockRect.maxY
        {
            blockHoverViewController.view.frame.origin.y = blockRect.origin.y
            blockHoverViewController.setHidden(false)
            dragState.mouseOverBlockRect = blockRect
            dragState.mouseOverBlock = block
        }
        else
        {
            blockHoverViewController.setHidden(true)
            dragState.mouseOverBlockRect = nil
            dragState.mouseOverBlock = nil
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
    
    

    
//case #selector(moveUpAndModifySelection(_:)),
//     #selector(moveLeftAndModifySelection(_:)),
//     #selector(moveWordLeftAndModifySelection(_:)),
//     #selector(moveToLeftEndOfLineAndModifySelection(_:)),
//     #selector(moveToBeginningOfParagraphAndModifySelection(_:)):
//    moveAndModifySelection(with: selector, inDirection: .upstream)
//
//case #selector(moveDownAndModifySelection(_:)),
//     #selector(moveRightAndModifySelection(_:)),
//     #selector(moveWordRightAndModifySelection(_:)),
//     #selector(moveToRightEndOfLineAndModifySelection(_:)),
//     #selector(moveToEndOfParagraphAndModifySelection(_:)):
    
    
    /// Handle when the user modifies the selection by means of the keyboard
    ///
    /// The types of command can be e.g.
    /// - moveLeftAndModifySelection -> shift + left arrow
    /// - moveWordRightAndModifySelection -> shift + option + right arrow
    /// - moveDownAndModifySelection -> shift + down arrow (= do multi block selection)
    /// - Warning
    /// - Sup brah
    /// - Parameters:
    ///   - command: command
    ///   - direction: direction
    private func moveAndModifySelection(with command: Selector, inDirection direction: NSSelectionAffinity) {
        let selected: NSRange
        let selectedBlock: Block

        switch selection
        {
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

    /// Runs when an NSStandardKeyBindingResponding event happened
    /// - Parameter selector: selector such as e.g. insertBacktab or moveLeft
    override func doCommand(by selector: Selector) {
        let isBlockMenuOpen = blockMenuViewController.isOpen

        // If the block menu is open, send the command to it to handle it, and it will return true if
        // it handled it and therefore TextView should not handle it
        if isBlockMenuOpen && blockMenuViewController.handle(command: selector) {
            return
        }

        switch selector
        {
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

        var blockRect = layoutManager.getBoundingRect(forBlock: block)

        if blockBeforeIndex >= 0
        {
            let blockBefore = blockStorage.blocks[blockBeforeIndex]
            let blockBeforeRect = layoutManager.getBoundingRect(forBlock: blockBefore)
            let gap = blockBeforeRect.maxY - blockRect.origin.y
            let gapMidpoint = gap / 2

            blockRect.origin.y -= gapMidpoint
            blockRect.size.height += gapMidpoint
        }

        if blockAfterIndex < blockStorage.blocks.count
        {
            let blockAfter = blockStorage.blocks[blockAfterIndex]
            let blockAfterRect = layoutManager.getBoundingRect(forBlock: blockAfter)
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
    
    /// Return the frame of the drop indicator and the block index of the block index where it is located
    /// - Parameters:
    ///   - location: current mouse location
    ///   - block: block at current mouse location
    ///   - layoutManager: layout manager
    /// - Returns: frame and block
    private func dragIndicatorPosition(draggingAt location: NSPoint, inBlock block: Block, layoutManager: BlockLayoutManager) -> (frame: NSRect, blockIndex: Int) {
        let inset = textContainerInset
        let width = frame.size.width - (inset.width * 2)

        let blockIndex = block.index
        let blockBeforeIndex = blockIndex - 1
        let blockAfterIndex = blockIndex + 1

        var blockRect = layoutManager.getBoundingRect(forBlock: block)

        if blockBeforeIndex >= 0
        {
            let blockBefore = blockStorage.blocks[blockBeforeIndex]
            let blockBeforeRect = layoutManager.getBoundingRect(forBlock: blockBefore)
            let gap = blockBeforeRect.maxY - blockRect.origin.y
            let gapMidpoint = gap / 2

            blockRect.origin.y -= gapMidpoint
            blockRect.size.height += gapMidpoint
        }

        if blockAfterIndex < blockStorage.blocks.count
        {
            let blockAfter = blockStorage.blocks[blockAfterIndex]
            let blockAfterRect = layoutManager.getBoundingRect(forBlock: blockAfter)
            let gap = blockAfterRect.origin.y - blockRect.maxY
            let gapMidpoint = gap / 2

            blockRect.size.height += gapMidpoint
        }

        blockRect.origin.y += inset.height

        if location.y < blockRect.midY
        {
            return (NSRect(x: inset.width, y: blockRect.origin.y - 2, width: width, height: 4), blockIndex)
        }
        else
        {
            return (NSRect(x: inset.width, y: blockRect.maxY - 2, width: width, height: 4), blockAfterIndex)
        }
    }
    
    /// When a dragging session ends. In this case, dragging a block or range of blocks and dropping it somewhere.
    /// - Parameters:
    ///   - session: the dragging session
    ///   - screenPoint: the point in the screen where it was dropped
    ///   - operation: type of drag operation
    override func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        super.draggingSession(session, endedAt: screenPoint, operation: operation)
//        insertionPoint.isHidden = false
    }

    @objc private func blockHoverViewMenuAction(_ menuItem: NSMenuItem) {
        let tag = menuItem.tag

        switch tag
        {
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
    
    /// When you click the :: symbol in the BlockHoverView, create an NSMenu with options like "Duplicate", "Delete", etc.
    /// - Returns: NSMenu
    func blockHoverViewContextMenu() -> NSMenu? {
        guard let mouseOverBlock = dragState.mouseOverBlock else {
            return nil
        }

        // Make top level menu item ("Delete", "Duplicate", "Turn into")
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

        // Create submenu item (i.e. the items under the "Turn into" header
        func makeTurnIntoSubmenuItem(withTitle title: String, tag: BlocksInfo.Types) -> NSMenuItem {
            let item = NSMenuItem()
                item.title = title
                item.tag = tag.rawValue
                item.target = self
                item.action = #selector(blockHoverViewMenuAction)
            
            return item
        }

        let index = mouseOverBlock.index // index of the block that's currently hovered over
        let blockRange: Range<Int>

        // If current selection is multiblock and the block that was clicked on is one of the selected blocks
        if case let .multiBlock(selectedBlockRange) = self.selection, selectedBlockRange.contains(index)
        {
            blockRange = selectedBlockRange
        }
        // Otherwise selec the block that was clicked on (overwriting previous selection)
        else
        {
            blockRange = index ..< index + 1
            setSelectedBlocks(blockRange)
        }

        // Current block selection (possibly changed in previous step)
        let blocks = blockStorage.blocks[blockRange]

        // NSMenu items to include in output
        var items = [
            makeMenuItem(withTitle: "Delete", image: "trash", tag: -1),
            makeMenuItem(withTitle: "Duplicate", image: "doc.on.doc", tag: -2)
        ]

        // If all selected blocks are convertable, add convert option to menu
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

        // If only one block is selected, (potentially) add specific menu items for that particular block type. For example ImageBlock has
        // "replace" and "download"
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
    
    /// Delete all blocks, but do it safely
    func clearDocument() {
        let numBlocks = blockStorage.blocks.count
        let selection = 0..<numBlocks
        let fullRange = blockStorage.getFullRange()
        
        blockStorage.deleteBlocks(inRange: selection, withCharacterRange: fullRange)
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

    // MARK: Dragging blocks
    
    /// Handle "Insert" option in BlockHoverView NSMenu. I.e. add a text block directly underneath.
    func blockHoverViewInsert() {
        if let block = dragState.mouseOverBlock {
            beginEditing()
            let inserted = blockStorage.createBlock(at: block.index + 1, ofType: .text)
            endEditing()
            
            setSelectedRange(NSRange(location: inserted.offset, length: 0), in: inserted.index)
        }
    }
    
    /// When you drag a block via the "Block Hover View" (the plus and drag symbol on the left)
    /// - Parameter event: NSEvent
    func blockHoverViewDidStartDragging(with event: NSEvent) {
        guard let mouseOverBlock = dragState.mouseOverBlock,
              let layoutManager = self.layoutManager as? BlockLayoutManager else {
            NSSound.beep()
            return
        }

        let dragRect: NSRect
        let dragRange: NSRange

        if case let .multiBlock(selectedBlockRange) = self.selection,
           selectedBlockRange.contains(mouseOverBlock.index),
           selectedBlockRange.count > 1
        {
            let firstBlock = blockStorage.blocks[selectedBlockRange.first!]
            let lastBlock = blockStorage.blocks[selectedBlockRange.last!]
            let topRect = layoutManager.getBoundingRect(forBlock: firstBlock)
            let bottomRect = layoutManager.getBoundingRect(forBlock: lastBlock)

            var blocksRect = NSUnionRect(topRect, bottomRect)
            blocksRect.origin.y += textContainerInset.height

            dragRect = blocksRect
            dragRange = blockStorage.characterRange(forBlockRange: selectedBlockRange)
            dragState.draggedBlocks = selectedBlockRange
        }
        else
        {
            let blockIndex = mouseOverBlock.index
            let inset = textContainerInset

            var rect = layoutManager.getBoundingRect(forBlock: mouseOverBlock)
            rect.origin.y += inset.height
            rect.origin.x = inset.width
            rect.size.width = frame.size.width - (inset.width * 2)

            dragRect = rect
            dragRange = mouseOverBlock.range
            dragState.draggedBlocks = blockIndex ..< blockIndex + 1
        }

        setSelectedRange(NSRange(location: blockStorage.length, length: 0), in: max(blockStorage.blocks.count - 1, 0))
        blockHoverViewController.setHidden(true, animate: false)
//        insertionPoint.isHidden = true

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
        if sender.draggingSource is TextView
        {
            return true
        }
        else
        {
            return super.prepareForDragOperation(sender)
        }
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let indicator = DraggedBlockDropIndicator(frame: NSRect())
        addSubview(indicator)

//        insertionPoint.isHidden = true
        dragState.dragType = DragType(info: sender)
        dragState.draggedBlockDropIndicator = indicator
        dragState.mouseOverBlock = nil

        return draggingUpdated(sender)
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        if let indicator = dragState.draggedBlockDropIndicator
        {
            indicator.removeFromSuperview()
            dragState.draggedBlockDropIndicator = nil
        }

        super.draggingExited(sender)
    }

    public override func draggingEnded(_ sender: NSDraggingInfo) {
        if let indicator = dragState.draggedBlockDropIndicator
        {
            indicator.removeFromSuperview()
            dragState.draggedBlockDropIndicator = nil
        }

//        insertionPoint.isHidden = false
    }
    
    /// This method runs at every moment of dragging (e.g. dragging a block, file, or image)
    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        // don't have to do anything special unless it's a block or image, just use default behavior then
        guard dragState.dragType != .default,
              let indicator = dragState.draggedBlockDropIndicator,
              let layoutManager = layoutManager as? BlockLayoutManager else {
            return super.draggingUpdated(sender)
        }

        let (location, _) = getAdjustedPoint(point: sender.draggingLocation)
        let character = characterIndexForInsertion(at: location)
        let block = blockStorage.block(at: character)

        dragState.mouseOverBlock = block
        let indicatorPosition = dragIndicatorPosition(draggingAt: location, inBlock: block, layoutManager: layoutManager)
        indicator.frame = indicatorPosition.frame

        if dragState.dragType == .block
        {
            return .private
        }
        else
        {
            return .copy
        }
    }

    /// This methods runs when a dragging operation is completed (let go of mouse)
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if dragState.dragType == .default {
            return super.performDragOperation(sender)
        }

        guard let layoutManager = self.layoutManager as? BlockLayoutManager else {
            return false
        }

        let (location, _) = getAdjustedPoint(point: sender.draggingLocation)
        let character = characterIndexForInsertion(at: location)
        let block = blockStorage.block(at: character)
        let position = dragIndicatorPosition(draggingAt: location, inBlock: block, layoutManager: layoutManager)

        switch dragState.dragType
        {
        case .block:
            return performBlockDragOperation(sender, at: position.blockIndex)

        case .image:
            return performImageDragOperation(sender, at: position.blockIndex)

        default:
            fatalError("Unreachable")
        }
    }

    // MARK: Pasting
    
    /// When user pastes some content, check the paste type and run the appropriate specialized paste method
    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        if let blockData = pasteboard.data(forType: NSPasteboard.PasteboardType(rawValue: "text.block"))
        {
            if let contents = try? CodedTextViewContents(data: blockData) {
                paste(contents: contents)
            }
        }
        else if let rtf = pasteboard.data(forType: .rtf), let string = NSAttributedString(rtf: rtf, documentAttributes: nil)
        {
            paste(attributedString: string)
        }
        else if let image = NSImage(pasteboard: pasteboard)
        {
            paste(image: image)
        }
        else if let html = pasteboard.data(forType: .html), let string = NSAttributedString(html: html, documentAttributes: nil)
        {
            paste(attributedString: string)
        }
        else if let text = pasteboard.string(forType: .string)
        {
            paste(markdown: text)
        }
    }

    /// Method to run when drag operation is completed if the drag type is block. I.e. if dragging a block.
    /// - Parameters:
    ///   - sender: NSDraggingInfo sender
    ///   - blockIndex: index to place block(s)
    /// - Returns: yes/no did succesfully perform block drag operation
    private func performBlockDragOperation(_ sender: NSDraggingInfo, at blockIndex: Int) -> Bool {
        guard let sourceTextView = sender.draggingSource as? TextView,
              let draggedBlockRange = sourceTextView.dragState.draggedBlocks else {
            return false
        }

        let sourceBlockStorage = sourceTextView.blockStorage
        var insertLocation = blockIndex

        if sourceTextView === self
        {
            if insertLocation >= draggedBlockRange.lowerBound && insertLocation <= draggedBlockRange.upperBound
            {
                setSelectedBlocks(draggedBlockRange)
                return true
            }

            if insertLocation > draggedBlockRange.lowerBound
            {
                insertLocation -= draggedBlockRange.count
            }
        }
        else
        {
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

        if blockStorage.mutableString.compare(text, options: .literal, range: inserted) == .orderedSame
        {
            let selected = LinkPopupController.SelectedText(text)

            if case .link = selected {
                setSelectedRange(inserted)
                popoverManager.displayLinkPopup(for: inserted, selection: selected)
                popoverManager.tick()
            }
        }
    }
    
    // TODO: Fix this method. block pasting is broken, It puts content in slightly weird places
    /// Get location where to insert content when pasting blocks
    /// - Returns: (blockIndex: block to begin pasting in -- characterIndex: where to begin adding characters)
    private func locationForBlockPaste() -> (blockIndex: Int, characterIndex: Int) {
        let blockIndex: Int
        let characterIndex: Int

        switch selection
        {
        case .singleBlock(let index, _):
            blockIndex = index + 1
            characterIndex = blockStorage.blocks[blockIndex - 1].range.upperBound

        case .multiBlock(let blockRange):
            blockIndex = blockRange.upperBound
            characterIndex = blockStorage.blocks[blockIndex - 1].range.upperBound

        case .none:
            blockIndex = 0 // blockStorage.blockRange(for: selectedRange()).upperBound
            characterIndex = 0 // blockStorage.blocks[blockIndex - 1].range.upperBound
        }

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

    private func paste(contents: CodedTextViewContents) {
        let codedBlocks = contents.blocks
        
        breakUndoCoalescing()
        beginEditing()

        let (blockIndex, characterIndex) = locationForBlockPaste() // (0, 0)
        let blockRange = blockStorage.createBlocks(from: codedBlocks, characterOffset: characterIndex, blockIndex: blockIndex)
            
        endEditing()

//        if blockRange.isEmpty {
//            NSSound.beep()
//        } else {
//            setSelectedBlocks(blockRange)
//        }
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
            popoverManager.displayLinkPopup(for: insertedRange, selection: selected)
            popoverManager.tick()
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

        if block.isSingleLine == false
        {
            let attributedString = attributedStringWithInlineStyles(fromMarkdown: markdown)
            blockStorage.replaceCharactersWithUndo(in: selected, with: attributedString)
            checkLinks(forPasteAt: selected.location, lengthBeforePaste: length)
            return
        }

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)

        if block.isEmpty
        {
            let blockIndex = block.index

            beginEditing()
            blockStorage.createBlocks(at: blockIndex + 1, withMarkdown: lines.map({String($0)}))
            blockStorage.deleteBlocks(inRange: blockIndex ..< blockIndex + 1, withCharacterRange: block.range)
            endEditing()
        }
        else if lines.count <= 1
        {
            let attributedString = attributedStringWithInlineStyles(fromMarkdown: markdown)
            blockStorage.replaceCharactersWithUndo(in: selected, with: attributedString)
        }
        else
        {
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
    
    // MARK: Copying
    
    override func copy(_ sender: Any?) {
        if case let .multiBlock(blockRange) = selection
        {
            copy(blocks: blockRange)
        }
        else
        {
            super.copy(sender)
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

        if codedBlocks.isEmpty == false,
           let json = try? JSONEncoder().encode(codedBlocks)
        {
            pasteboard.setData(json, forType: NSPasteboard.PasteboardType(rawValue: "text.block"))
        }
        else
        {
            NSSound.beep()
        }
    }
}
