import Cocoa

protocol StringBasedBlockCoded {
    var string: String { get }
}

/// Generic block base class.
///
/// A block owns a range of characters in a text storage class. It provides custom styling, and
/// custom text editing behavior for the region it covers. Blocks maintain a view into their parent
/// text storage object. Before calling any methods on a Block, ensure that the blocks index and
/// offset properties have been set.
class Block {
    unowned var blockStorage: TextBlockStorage
    var textStorage: NSTextStorage

    var type: BlocksInfo.Types
    var style: StyleBuilder

    var index: Int
    var length: Int
    var offset: Int

    /// Designated initializer for the base class.
    /// Subclasses should use this initializer to set the blocks type and style.
    ///
    /// - Parameter owner:  The TextBlockStorage that owns this block.
    /// - Parameter type:   The block type.
    /// - Parameter style:  The block style.
    /// - Parameter length: The block's length in UTF-16 code points (i.e. NSSring.length).
    /// - Parameter index:  The index of the block in the owner's blocks array.
    /// - Parameter offset: The character offset of the block (in UTF-16 codepoints) in the owner's text storage.
    public init(owner: TextBlockStorage, type: BlocksInfo.Types, style: StyleBuilder, range: NSRange, index: Int) {
        self.blockStorage = owner
        self.textStorage = owner.underlyingTextStorage
        self.type = type
        self.style = style
        self.index = index
        self.length = range.length
        self.offset = range.location
    }

    required init(copy: Block) {
        self.blockStorage = copy.blockStorage
        self.textStorage = copy.textStorage
        self.type = copy.type
        self.style = copy.style
        self.index = copy.index
        self.length = copy.length
        self.offset = copy.offset
    }

    public init(owner: TextBlockStorage, type: BlocksInfo.Types, style: StyleBuilder, string: String, inlineStyles: [StyleBuilder.Coded], offset: Int, index: Int) throws {
        let content = NSAttributedString(string: string)
        let textView = owner.textView!
        let replaceRange = NSRange(location: offset, length: 0)
        let range = NSRange(location: offset, length: content.length)

        self.blockStorage = owner
        self.textStorage = blockStorage.underlyingTextStorage
        self.type = type
        self.style = style
        self.index = index
        self.length = range.length
        self.offset = range.location

        textView.shouldChangeText(in: replaceRange, replacementString: content.string)
        textStorage.insert(content, at: offset)
        blockStorage.edited([.editedCharacters, .editedAttributes], range: replaceRange, changeInLength: range.length)
        textView.didChangeText()
        
        for style in inlineStyles {
            let range = toParentRange(blockRange: style.range)
            textView.shouldChangeText(in: range, replacementString: nil)
            textStorage.addAttributes(style.attributes, range: range)
            blockStorage.edited([.editedAttributes], range: range, changeInLength: 0)
            textView.didChangeText()
        }
        
        applyStyles()
    }
    
    struct Coded: Codable, StringBasedBlockCoded {
        let string: String
        let inlineStyles: [StyleBuilder.Coded]
        
        init(_ block: Block) {
            let attributed = block.textStorage.attributedSubstring(from: block.range)
            self.string = attributed.string
            
            var inlineStyles = [StyleBuilder.Coded]()
            
            attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length), options: .longestEffectiveRangeNotRequired, using: { (values, range, stop) in
                var attributes: [NSAttributedString.Key: Any] = [:]
                
                if let styles = values[.inlineStyle] as? StyleBuilder.InlineStyles, styles != StyleBuilder.InlineStyles.none
                {
                    attributes[.inlineStyle] = styles
                }
    
                if let link = values[.link] as? URL
                {
                    attributes[.link] = link
                }
    
                if let pageLink = values[.pageLinkTo] as? Int
                {
                    attributes[.pageLinkTo] = pageLink
                }
                
                if attributes.isEmpty == false
                {
                    inlineStyles.append(StyleBuilder.Coded(range: range, attributes: attributes))
                }
            })
            
            self.inlineStyles = inlineStyles
        }
        
        init(string: String) {
            self.string = string
            self.inlineStyles = []
        }
    }

    func copy() -> (block: Block, content: NSAttributedString) {
        let content = textStorage.attributedSubstring(from: range)
        let block = Swift.type(of: self).init(copy: self)
        return (block, content)
    }
    
    /// The range of the block in its underlying text storage.
    final var range: NSRange {
        return NSRange(location: offset, length: length)
    }

    var isTextSelectable: Bool {
        return true
    }

    var textRange: NSRange {
        return NSRange(location: offset, length: length)
    }

    var isSingleLine: Bool {
        return true
    }

    var isConvertable: Bool {
        return true
    }

    /// Convert a parent range to a block range.
    /// A block range is a range offset by the blocks position, such that index 0 is the first character in the block.
    /// - See: toParentRange(blockRange:)
    final func toBlockRange(parentRange range: NSRange) -> NSRange {
        return NSRange(location: range.location - offset, length: range.length)
    }

    /// Convert a block range to a parent range.
    /// - See: toBlockRange(parentrange:)
    final func toParentRange(blockRange range: NSRange) -> NSRange {
        return NSRange(location: range.location + offset, length: range.length)
    }

    func didRemove() {
        return
    }

    func applyStyles(withUndo: Bool = false) {
        let range = self.range

        guard range.length != 0, let textView = blockStorage.textView else {
            return
        }

        // TODO: Implement some sort of dirty range mechanism. This could be painful on large blocks.
        textStorage.enumerateAttributes(in: range, options: [.longestEffectiveRangeNotRequired]) {attributes, range, stop in
            if let blockType = attributes[.blockType] as? BlocksInfo.Types, blockType == self.type {
                return
            }

            if withUndo == false || textView.shouldChangeText(in: range, replacementString: nil) {
                let inlineStyles = attributes[.inlineStyle] as? StyleBuilder.InlineStyles ?? []
                let adjustedAttributes = style.attributes(attributes, withStyles: inlineStyles)

                textStorage.setAttributes(adjustedAttributes, range: range)
                blockStorage.edited([.editedAttributes], range: range, changeInLength: 0)

                if withUndo {
                    textView.didChangeText()
                }
            }
        }

        if endsWithNewlineCharacter() {
            textStorage.setAttributes(style.attributes, range: NSRange(location: range.upperBound - 1, length: 1))
            blockStorage.edited([.editedAttributes], range: range, changeInLength: 0)
        }
    }

    func createBlocks(for range: NSRange, atIndex blockIndex: Int, startingOffset blockOffset: Int) {
        let string = textStorage.mutableString
        var index = blockIndex

        if range.length == 0 {
            let lineBlock = TextBlock(owner: blockStorage, range: NSRange())
            blockStorage.insertBlock(lineBlock, at: index)
            return
        }

        var blocks = [Block]()
        var offset = blockOffset

        string.enumerateSubstrings(in: range, options: [.byLines, .substringNotRequired]) {[blockStorage] _, _, lineRange, _ in
            let lineBlock = TextBlock(owner: blockStorage, range: NSRange(location: offset, length: lineRange.length))
            lineBlock.applyStyles()

            blocks.append(lineBlock)
            offset += lineRange.length
            index += 1
        }
        
        blockStorage.insertBlocks(contentsOf: blocks, at: blockIndex)
    }

    func willMerge(didDeleteCharacters deletedCount: Int = 0) -> Int {
        return length - deletedCount
    }

    func willConvert() -> NSRange {
        return NSRange(location: offset, length: length)
    }
    
    // MARK: Before/after edits and undo/redos

    func willEdit(_ edit: BlockEdit) {
        if case .replaceWithLines = edit {
            blockStorage.textView?.breakUndoCoalescing()
        }
    }

    func didEdit(_ edit: BlockEdit) {
        switch edit
        {
        case .deleteLastCharacter:
            return didDeleteLastCharacter()

        case .multiBlockEdit(let range, let string):
            return _didReplaceCharacters(inMultiBlockRange: range, with: string)

        case .replaceWithLines(let range, let string, let firstNewline):
            return _didReplaceCharacters(in: range, withLines: string, firstNewlineAt: firstNewline)

        case .replace(let range, let string):
            return _didReplaceCharacters(in: range, with: string)

        case .insert(let range, let string):
            return _didInsertCharacters(at: range.location, with: string)
        }
    }

    func didUndoOrRedo(offset: Int, length: Int, index: Int) {
        self.offset = offset
        self.length = length
        self.index = index
    }
    
    func didDeleteLastCharacter() {
        length -= 1

        if let next = blockStorage.block(after: self) {
            length += next.willMerge()
            blockStorage.removeBlock(at: next.index)
            applyStyles()
        }
    }
    
    func _didReplaceCharacters(inMultiBlockRange range: NSRange, with string: String) {
        let stringLength = string.utf16.count
        let changeInLength = stringLength - range.length
        let editedBlocksRange = blockStorage.blockRange(for: range)
        let editedBlocks = blockStorage.blocks[editedBlocksRange]

        let lastBlock = editedBlocks.last!
        let lastBlockOffset = lastBlock.offset

        lastBlock.offset += changeInLength

        let lastBlockLength = lastBlock.willMerge(didDeleteCharacters: range.upperBound - lastBlockOffset)
        let remainingLength = range.location - offset

        if remainingLength == 0
        {
            let unownedRange = NSRange(location: range.location, length: stringLength + lastBlockLength)
            blockStorage.removeBlock(range: editedBlocksRange)

            if unownedRange.length != 0
            {
                let oldBlocksCount = blockStorage.blocks.count
                createBlocks(for: unownedRange, atIndex: index, startingOffset: offset)
                
                if !string.hasSuffix("\n")
                {
                    let numCreatedBlocks = blockStorage.blocks.count - oldBlocksCount
                    let lastNewBlock = blockStorage.blocks[index + numCreatedBlocks - 1]
                    let addLineBreakRange = NSRange(location: unownedRange.upperBound, length: 0)
                    
                    blockStorage.textView.addDeferredCommand(DeferredSelectionCommand(selection: NSRange(location: addLineBreakRange.upperBound, length: 0)))
                    blockStorage.textView.shouldChangeText(in: addLineBreakRange, replacementString: "\n")
                    textStorage.replaceCharacters(in: addLineBreakRange, with: "\n")
                    blockStorage.edited([.editedCharacters], range: addLineBreakRange, changeInLength: 1)
                    blockStorage.textView.didChangeText()
                    
                    lastNewBlock.length += 1
                    blockStorage.updateBlocks()
                }
            }

            return
        }
        
        fatalError("Hypothesis: This code is never reached. Testing.")

//        blockStorage.removeBlock(range: index + 1 ..< lastBlock.index + 1)
//
//        if let newlineIndex = string.firstIndex(where: {$0.isNewline}) {
//            let inserted = string[string.startIndex ..< newlineIndex].utf16.count + 1
//            let unownedRange = NSRange(location: range.location + inserted, length: stringLength + lastBlockLength - inserted)
//
//            length = remainingLength + inserted
//            createBlocks(for: unownedRange, atIndex: index + 1, startingOffset: offset + length)
//        } else {
//            length = remainingLength + stringLength + lastBlockLength
//        }
//
//        applyStyles()
    }

    func _didReplaceCharacters(in range: NSRange, withLines string: String, firstNewlineAt newlineIndex: String.Index) {
        let stringLength = string.utf16.count
        let rangeBlockLocation = range.location - offset

        let inserted = string[string.startIndex ..< newlineIndex].utf16.count + 1
        let remaining = stringLength - inserted
        let moved = length - range.length - rangeBlockLocation

        length = rangeBlockLocation + inserted
        applyStyles()

        let unownedRange = NSRange(location: range.location + inserted, length: moved + remaining)
        createBlocks(for: unownedRange, atIndex: index + 1, startingOffset: offset + length)
    }

    func _didReplaceCharacters(in range: NSRange, with string: String) {
        length += (string.utf16.count - range.length)

        if length != 0 {
            applyStyles()
        } else {
            let index = self.index

            if index != blockStorage.blocks.count - 1 {
                blockStorage.removeBlock(at: index)
            }
        }
    }

    func _didInsertCharacters(at characterIndex: Int, with string: String) {
        length += string.utf16.count
        _processMarkdown(in: string, at: characterIndex)
    }

    // MARK: Handle markdown
    
    private func markdownConvert(markdownRange: NSRange, type: BlocksInfo.Types) {
        let textView = blockStorage.textView!
        
        textView.breakUndoCoalescing()

        textView.shouldChangeText(in: markdownRange, replacementString: "")
        textStorage.replaceCharacters(in: markdownRange, with: "")
        blockStorage.edited([.editedCharacters], range: markdownRange, changeInLength: -markdownRange.length)
        textView.didChangeText()

        length -= markdownRange.length

        let index = self.index
        let convertRange = willConvert()
        let converted: Block

        switch type
        {
        case .header1:
            converted = Header1Block(owner: blockStorage, range: convertRange, index: index)

        case .header2:
            converted = Header2Block(owner: blockStorage, range: convertRange, index: index)

        case .list:
            converted = ListBlock(owner: blockStorage, range: convertRange, index: index)

        case .orderedlist:
            converted = OrderedListBlock(owner: blockStorage, range: convertRange, index: index)

        case .codesnippet:
            converted = CodeBlock(owner: blockStorage, range: convertRange, index: index, isLast: index == (blockStorage.blocks.count - 1))

        default:
            fatalError("Invalid block type")
        }

        blockStorage.replaceBlock(at: index, with: converted)
        converted.applyStyles(withUndo: true)
        textView.breakUndoCoalescing()
        
//        textView.addDeferredCommand(DeferredSelectionCommand(selection: NSRange(location: converted.textRange.location, length: 0)))
    }

    private func markdownApplyStyle(openingMarkdown: NSRange, closingMarkdown: NSRange, style styleFlag: StyleBuilder.InlineStyles) {
        let range = NSRange(location: openingMarkdown.location, length: closingMarkdown.location - openingMarkdown.upperBound)

        guard range.length > 0, let textView = blockStorage.textView else {
            return
        }

        textView.breakUndoCoalescing()

        if textView.shouldChangeText(in: closingMarkdown, replacementString: "")
        {
            textStorage.replaceCharacters(in: closingMarkdown, with: "")
            blockStorage.edited([.editedCharacters], range: closingMarkdown, changeInLength: -closingMarkdown.length)
            textView.didChangeText()

            length -= closingMarkdown.length
        }

        if textView.shouldChangeText(in: openingMarkdown, replacementString: "")
        {
            textStorage.replaceCharacters(in: openingMarkdown, with: "")
            blockStorage.edited([.editedCharacters], range: openingMarkdown, changeInLength: -closingMarkdown.length)
            textView.didChangeText()

            length -= openingMarkdown.length
        }

        for (attributes, range) in textStorage.attributeRuns(in: range) {
            guard let styles = attributes[.inlineStyle] as? StyleBuilder.InlineStyles else {
                continue
            }

            let adjustedStyles = styles.inserting(styleFlag)
            let adjustedAttributes = style.attributes(attributes, withStyles: adjustedStyles)

            if textView.shouldChangeText(in: range, replacementString: nil)
            {
                textStorage.setAttributes(adjustedAttributes, range: range)
                blockStorage.edited([.editedAttributes], range: range, changeInLength: 0)
                textView.didChangeText()
            }
        }
    }

    private func markdownHandleSingleAsterisk(in string: NSString, range: NSRange, at characterIndex: Int, behind: NSRange, ahead: NSRange) {
        if behind.length > 0, let scalar = Unicode.Scalar(string.character(at: behind.upperBound - 1)), Character(scalar).isWhitespace == false {
            let regex = try! NSRegularExpression(pattern: "(^|[^\\*])(\\*)([^\\*\\s])", options: [])
            let matches = regex.matches(in: string as String, options: [], range: behind)

            if let lastMatch = matches.last {
                let first = lastMatch.range(at: 2)
                let second = NSRange(location: characterIndex, length: 1)
                return markdownApplyStyle(openingMarkdown: first, closingMarkdown: second, style: .bold)
            }
        }

        if ahead.length > 0, let scalar = Unicode.Scalar(string.character(at: ahead.location)), Character(scalar).isWhitespace == false {
            let regex = try! NSRegularExpression(pattern: "[^\\*\\s](\\*)([^\\*]|$)", options: [])
            let matches = regex.matches(in: string as String, options: [], range: ahead)

            if let firstMatch = matches.first {
                let first = NSRange(location: characterIndex, length: 1)
                let second = firstMatch.range(at: 1)
                return markdownApplyStyle(openingMarkdown: first, closingMarkdown: second, style: .bold)
            }
        }
    }

    private func markdownHandleDoubleAsterisk(in string: NSString, range: NSRange, at characterIndex: Int, behind: NSRange, ahead: NSRange) {
        if behind.length > 0, let scalar = Unicode.Scalar(string.character(at: behind.upperBound - 1)), Character(scalar).isWhitespace == false {
            let regex = try! NSRegularExpression(pattern: "(\\*\\*)([^\\*\\s])", options: [])
            let matches = regex.matches(in: string as String, options: [], range: behind)

            if let lastMatch = matches.last {
                let first = lastMatch.range(at: 1)
                let second = NSRange(location: behind.upperBound, length: 2)
                return markdownApplyStyle(openingMarkdown: first, closingMarkdown: second, style: .italic)
            }
        }

        if ahead.length > 0, let scalar = Unicode.Scalar(string.character(at: ahead.location)), Character(scalar).isWhitespace == false {
            let regex = try! NSRegularExpression(pattern: "([^\\*\\s])(\\*\\*)", options: [])
            let matches = regex.matches(in: string as String, options: [], range: ahead)

            if let firstMatch = matches.first {
                let first = NSRange(location: ahead.location - 2, length: 2)
                let second = firstMatch.range(at: 2)
                return markdownApplyStyle(openingMarkdown: first, closingMarkdown: second, style: .italic)
            }
        }
    }

    private func markdownHandleAsterisk(in string: NSString, range: NSRange, at characterIndex: Int) {
        applyStyles()

        let nonAstreisk = CharacterSet(["*"]).inverted
        var behind = NSRange(location: range.location, length: characterIndex - range.location)
        let behindStart = string.rangeOfCharacter(from: nonAstreisk, options: [.backwards, .literal], range: behind)

        if behindStart.length != 0 {
            behind.length = (behindStart.location - range.location + 1)
        }

        let behindEnd = behind.upperBound
        let aheadStart = characterIndex + 1
        var ahead = NSRange(location: aheadStart, length: range.upperBound - aheadStart)
        let aheadEnd = string.rangeOfCharacter(from: nonAstreisk, options: .literal, range: ahead)

        if aheadEnd.length != 0 {
            ahead.location = aheadEnd.upperBound - 1
            ahead.length = range.upperBound - ahead.location
        }

        if (ahead.location - behindEnd) == 1 {
            markdownHandleSingleAsterisk(in: string, range: range, at: characterIndex, behind: behind, ahead: ahead)
        } else {
            markdownHandleDoubleAsterisk(in: string, range: range, at: characterIndex, behind: behind, ahead: ahead)
        }
    }

    private func markdownHandleBacktick(in string: NSString, range: NSRange, at characterIndex: Int) {
        if range.length >= 3 && characterIndex <= (range.location + 3) {
            let fenceRange = NSRange(location: range.location, length: 3)
            let remainingRange = NSRange(location: range.location + 3, length: range.length - 3)
            let nonWhitespace = NSCharacterSet.whitespacesAndNewlines.inverted

            if string.compare("```", options: .literal, range: fenceRange) == .orderedSame,
               string.rangeOfCharacter(from: nonWhitespace, options: [], range: remainingRange).location == NSNotFound {
                return markdownConvert(markdownRange: fenceRange, type: .codesnippet)
            }
        }

        let backtick = CharacterSet(["`"])
        let behind = NSRange(location: range.location, length: characterIndex - range.location)

        if behind.length > 0 {
            let first = string.rangeOfCharacter(from: backtick, options: [.literal, .backwards], range: behind)

            if first.length != 0 {
                let second = NSRange(location: characterIndex, length: 1)
                return markdownApplyStyle(openingMarkdown: first, closingMarkdown: second, style: .code)
            }
        }

        let aheadLocation = characterIndex + 1
        let ahead = NSRange(location: aheadLocation, length: range.upperBound - aheadLocation)

        if ahead.length > 0 {
            let second = string.rangeOfCharacter(from: backtick, options: [.literal], range: ahead)

            if second.length != 0 {
                let first = NSRange(location: characterIndex, length: 1)
                return markdownApplyStyle(openingMarkdown: first, closingMarkdown: second, style: .code)
            }
        }
    }
    
    /// Process markdown upon text insertion.
    /// Both
    /// -block types markdown (e.g. "#" + "space" + at beginning of line -> turn into H1)
    /// -and inline types markdown like this "**italic**"
    /// - Parameters:
    ///   - inserted: inserted text
    ///   - index: character index of inserted text
    func _processMarkdown(in inserted: String, at index: Int) {
        let text = textStorage.mutableString
        let textRange = self.textRange

        switch inserted
        {
        case " " where index == (textRange.location + 1):
            let compareRange = NSRange(location: textRange.location, length: 1)

            if text.compare("#", options: .literal, range: compareRange) == .orderedSame
            {
                return markdownConvert(markdownRange: NSRange(location: textRange.location, length: 2), type: .header1)
            }
            else if text.compare("*", options: .literal, range: compareRange) == .orderedSame
            {
                return markdownConvert(markdownRange: NSRange(location: textRange.location, length: 2), type: .list)
            }
            else if text.compare("-", options: .literal, range: compareRange) == .orderedSame
            {
                return markdownConvert(markdownRange: NSRange(location: textRange.location, length: 2), type: .list)
            }

        case " " where index == (textRange.location + 2):
            let compareRange = NSRange(location: textRange.location, length: 2)

            if text.compare("##", options: .literal, range: compareRange) == .orderedSame
            {
                return markdownConvert(markdownRange: NSRange(location: textRange.location, length: 3), type: .header2)
            }
            else if text.compare("1.", options: .literal, range: compareRange) == .orderedSame
            {
                return markdownConvert(markdownRange: NSRange(location: textRange.location, length: 3), type: .orderedlist)
            }
            
        case "*":
            markdownHandleAsterisk(in: text, range: textRange, at: index)

        case "`":
            markdownHandleBacktick(in: text, range: textRange, at: index)
        
        case "[":
            let compareRange = NSRange(location: index - 1, length: 2)
            
            if text.compare("[[", options: .literal, range: compareRange) == .orderedSame
            {
                let textView = blockStorage.textView!
                textView.addDeferredCommand(DeferredSelectionCommand(selection: compareRange))
                textView.addDeferredCommand(DisplayPageLinkPopup(selection: compareRange))
            }
        default:
            applyStyles(withUndo: false)
        }
    }

    // MARK: Toggle inline styling
    
    /// Toggle inline styles in the given range.
    ///
    /// When the given inline style is present anywhere in the given range, the style is removed for the whole range.
    /// If the style is not present anywhere in the range, then the style is applied to the whole range. Existing inline
    /// styles are preserved.
    ///
    /// - Parameter inlineStyle:    The inline style to toggle.
    /// - Parameter range:          The range to toggle the style in.
    public func toggleStyle(_ styleFlag: StyleBuilder.InlineStyles, in range: NSRange) {
        let currentAttributes = textStorage.attributeRuns(in: range)
        var didReverse = false

        for (attributes, range) in currentAttributes {
            if let styles = attributes[.inlineStyle] as? StyleBuilder.InlineStyles, styles.contains(styleFlag) {
                let adjustedStyles = styles.removing(styleFlag)
                let adjustedAttributes = style.attributes(attributes, withStyles: adjustedStyles)
                textStorage.setAttributes(adjustedAttributes, range: range)

                didReverse = true
            }
        }

        if didReverse == false
        {
            for (attributes, range) in currentAttributes {
                var adjustedStyles = attributes[.inlineStyle] as? StyleBuilder.InlineStyles ?? []
                adjustedStyles.insert(styleFlag)

                let adjustedAttributes = style.attributes(attributes, withStyles: adjustedStyles)
                textStorage.setAttributes(adjustedAttributes, range: range)
            }
        }
    }

    // MARK: Handle specific insertions and deletions
    
    func insertTab(at: Int) -> Bool {
        return false
    }

    func insertBacktab(at: Int) -> Bool {
        return false
    }

    func insertNewline(at location: Int) -> Bool {
        if location != 0 {
            return false
        }

        let textView = blockStorage.textView!

        textView.beginEditing()
        blockStorage.createBlock(at: index, ofType: .text)
        textView.endEditing()
        return true
    }

    func deleteForward(at: Int) -> Bool {
        return false
    }

    func deleteBackward(at: Int) -> Bool {
        return false
    }

    // MARK: Background drawing
    
    var alwaysDrawsBackground: Bool {
        return false
    }

    /// Draws the block's background.
    /// - Parameter blockRect: The bounding rect of the block in the parent text view.
    /// - Parameter isSelected: Indicates that the block is selected as part of a multiblock selection.
    func drawBackground(in blockRect: NSRect, isSelected: Bool) {
        guard isSelected else {
            return
        }

        NSColor.textBackgroundColor.setFill()
        blockRect.fill()

        var adjustedRect = blockRect
        adjustedRect.origin.x -= 4
        adjustedRect.size.width += 4

        if (index + 1) != blockStorage.blocks.count {
            adjustedRect.size.height -= 4
        }

        NSColor(srgbRed: 218/255, green: 238/255, blue: 248/255, alpha: 1).setFill()
        adjustedRect.fill()
    }

    var adjustsLayout: Bool {
        return false
    }

    func adjustLayout(layoutManager: NSLayoutManager,
                      lineFragmentRect: UnsafeMutablePointer<NSRect>,
                      lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
                      baselineOffset: UnsafeMutablePointer<CGFloat>,
                      characterRange: NSRange) -> Bool {
        return false
    }

    /// Check if block ends with new line character
    func endsWithNewlineCharacter() -> Bool {
        return index < (blockStorage.blocks.count - 1) || (length > 0 && blockStorage.mutableString.hasSuffix("\n"))
    }

    /// Check if block is empty (excluding potential newline character)
    var isEmpty: Bool {
        return length == (endsWithNewlineCharacter() ? 1 : 0)
    }
    
    /// Check if it is possible to extend the text selection any further.
    /// - Parameters:
    ///   - range: current selection
    ///   - direction: direction of selection, upstream or downstream
    /// - Returns: whether it is possible to extend the selection further
    ///
    /// How is this used? If it is not possible to extend selection any further, it turns into multi-block selection mode
    func canExtendSelection(_ range: NSRange, inDirection direction: NSSelectionAffinity) -> Bool {
        if direction == .upstream {
            return range.location != offset
        } else {
            let newlineAdjustment = endsWithNewlineCharacter() ? 1 : 0
            return (range.location + range.length) != (offset + length - newlineAdjustment)
        }
    }

    func adjustSelection(_ selection: NSRange, inDirection: NSSelectionAffinity) -> NSRange? {
        var blockRange = self.range

        if endsWithNewlineCharacter() {
            blockRange.length -= 1
        } else {
            blockRange.length += 1
        }

        if let intersection = blockRange.intersection(selection) {
            return intersection
        } else if blockRange.location > selection.location {
            return NSRange(location: blockRange.location, length: 0)
        } else {
            return NSRange(location: blockRange.upperBound, length: 0)
        }
    }

    /// Whether this block needs to do anything when an adjacent block is updated
    var wantsAdjacentBlockUpdates: Bool {
        return false
    }
    
    // TODO: Should probably rename to adjacentBlockDidChange ?
    /// Method to run when block adjacent to this one changes (overwrite in subclass if relevant to a block type)
    /// - Parameter positioned: the position of the block that changed relative (above or below) to the block that runs this
    func adjacentBlockDidChange(positioned: BlockPosition) {
        return
    }

    func contextMenuItems() -> [NSMenuItem] {
        return []
    }
}
