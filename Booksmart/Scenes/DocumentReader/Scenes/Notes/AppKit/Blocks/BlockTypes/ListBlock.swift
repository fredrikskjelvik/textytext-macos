import Cocoa

/// Indentation from the start of the line to the bullet.
fileprivate let bulletIndentLevel: CGFloat = 20

/// Indentation from after the bullet to the start of text.
fileprivate let textIndentLevel: CGFloat = 20

/// The amount nested lists are incremented by.
fileprivate let indentIncrement: CGFloat = 20

fileprivate func listStyle(forIndentationLevel indentationLevel: Int) -> StyleBuilder {
    let bulletPosition = bulletIndentLevel + (indentIncrement * CGFloat(indentationLevel))
    let textPosition = bulletPosition + textIndentLevel

    let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 5.0
        paragraphStyle.firstLineHeadIndent = bulletPosition
        paragraphStyle.headIndent = textPosition
        paragraphStyle.tabStops = [NSTextTab(type: .leftTabStopType, location: textPosition)]
        paragraphStyle.defaultTabInterval = 28

    let attributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.Monochrome.RegularBlack,
        .font: NSFont.systemFont(ofSize: 18.0),
        .paragraphStyle: paragraphStyle,
        .blockType: BlocksInfo.Types.list,
        .inlineStyle: StyleBuilder.InlineStyles.none
    ]

    return StyleBuilder(attributes: attributes)
}

fileprivate func markerString(forIndentationLevel indentationLevel: Int) -> String {
    switch indentationLevel
    {
    case 1:  return "▪\t"
    case 2:  return "◦\t"
    case 3:  return "‣\t"
    case 4:  return "⁃\t"
    default: return "•\t"
    }
}

class ListBlock: Block {
    let indentationLevel: Int
    var markerLength: Int

    var maxIndentationLevel: Int {
        return 4
    }

    init(owner: TextBlockStorage, type: BlocksInfo.Types, style: StyleBuilder, range: NSRange, index: Int, indentationLevel: Int, markerLength: Int, markerString: String?) {
        self.indentationLevel = indentationLevel
        self.markerLength = markerLength
        super.init(owner: owner, type: type, style: style, range: range, index: index)

        if let marker = markerString {
            placeMarker(markerString: marker)
        }
    }

    convenience init(owner: TextBlockStorage, range: NSRange, index: Int = 0, indentationLevel: Int = 0) {
        let adjustedIndentationLevel = min(indentationLevel, 4)
        let style = listStyle(forIndentationLevel: adjustedIndentationLevel)
        let marker = markerString(forIndentationLevel: adjustedIndentationLevel)
        self.init(owner: owner, type: .list, style: style, range: range, index: index, indentationLevel: adjustedIndentationLevel, markerLength: 0, markerString: marker)
    }

    required init(copy block: Block) {
        if let listBlock = block as? ListBlock
        {
            self.indentationLevel = listBlock.indentationLevel
            self.markerLength = listBlock.markerLength
        }
        else
        {
            self.indentationLevel = 0
            self.markerLength = 0
        }

        super.init(copy: block)
    }

    init(from coded: Coded, owner: TextBlockStorage, offset: Int, index: Int) throws {
        self.indentationLevel = coded.indentationLevel
        self.markerLength = coded.markerLength
        try super.init(owner: owner, type: .list, style: listStyle(forIndentationLevel: indentationLevel), string: coded.string, inlineStyles: coded.inlineStyles, offset: offset, index: index)
    }
    
    struct Coded: Codable, StringBasedBlockCoded {
        let indentationLevel: Int
        let markerLength: Int
        let string: String
        let inlineStyles: [StyleBuilder.Coded]
        
        init(_ block: Block) throws {
            guard let listBlock = block as? ListBlock else {
                throw BlockCodingError.invalidType
            }
            
            let attributed = block.textStorage.attributedSubstring(from: block.range)
            
            self.string = attributed.string
            self.indentationLevel = listBlock.indentationLevel
            self.markerLength = listBlock.markerLength
            
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
    }

    override var textRange: NSRange {
        return NSRange(location: offset + markerLength, length: length - markerLength)
    }

    public func placeMarker(markerString: String) {
        guard let textView = blockStorage.textView else {
            return
        }

        let markerRange = NSRange(location: offset, length: markerLength)

        if textView.shouldChangeText(in: markerRange, replacementString: markerString) {
            let oldMarkerLength = markerLength
            let newMarkerLength = markerString.utf16.count
            let changeInLength = newMarkerLength - oldMarkerLength

            markerLength = newMarkerLength
            length += changeInLength

            textStorage.replaceCharacters(in: markerRange, with: markerString)
            textStorage.setAttributes(style.attributes, range: NSRange(location: offset, length: newMarkerLength))
            blockStorage.edited([.editedCharacters, .editedAttributes], range: markerRange, changeInLength: changeInLength)
            textView.didChangeText()
            
//            textView.addDeferredCommand(DeferredSelectionCommand(selection: NSRange(location: offset + newMarkerLength, length: 0)))
        }
    }

    override func willConvert() -> NSRange {
        var deletedChars = 0

        if markerLength != 0, let textView = blockStorage.textView {
            let markerRange = NSRange(location: offset, length: markerLength)

            if textView.shouldChangeText(in: markerRange, replacementString: "") {
                textStorage.deleteCharacters(in: markerRange)
                blockStorage.edited([.editedCharacters, .editedAttributes], range: markerRange, changeInLength: -markerLength)
                textView.didChangeText()
                deletedChars = markerLength
            }
        }

        return NSRange(location: offset, length: length - deletedChars)
    }

    private func deleteCharacters(in range: NSRange) {
        if let textView = blockStorage.textView, textView.shouldChangeText(in: range, replacementString: "") {
            textStorage.replaceCharacters(in: range, with: "")
            blockStorage.edited([.editedCharacters], range: range, changeInLength: -range.length)
            textView.didChangeText()
            length -= range.length
        }
    }

    override func _didReplaceCharacters(in range: NSRange, with string: String) {
        let markerEnd = offset + markerLength

        if range.location >= markerEnd {
            return super._didReplaceCharacters(in: range, with: string)
        }

        // Handle edits to the list marker. These shouldn't be possible. They should be prohibited by our selection
        // handling code, that is to say this range should be neither selectable nor editable. At the moment it is,
        // so we should handle it in a semi sane way. Delete any remnant marker characters and convert to TextBlock.
        let stringLength = string.utf16.count
        let rangeUpperBound = range.upperBound

        if rangeUpperBound < markerEnd {
            let markerSuffix = NSRange(location: rangeUpperBound + stringLength, length: markerEnd - rangeUpperBound)
            deleteCharacters(in: markerSuffix)
        }

        if range.location > 0 {
            let markerPrefix = NSRange(location: offset, length: range.location - offset)
            deleteCharacters(in: markerPrefix)
        }

        let textBlock = TextBlock(owner: self.blockStorage, range: self.range, index: self.index)
        blockStorage.replaceBlock(at: index, with: textBlock)
        textBlock._didReplaceCharacters(in: range, with: string)
    }

    /// Remove marker characters before the block is merged into another.
    override func willMerge(didDeleteCharacters deletedCount: Int = 0) -> Int {
        let newLength = length - deletedCount

        if deletedCount >= markerLength {
            return newLength
        }

        let offset = self.offset
        let textView = blockStorage.textView!
        let markerRange = NSRange(location: offset + deletedCount, length: markerLength - deletedCount)

        textView.addDeferredCommand(DeferredSelectionCommand(selection: NSRange(location: offset, length: 0)))

        textView.shouldChangeText(in: markerRange, replacementString: "")
        textStorage.replaceCharacters(in: markerRange, with: "")
        blockStorage.edited([.editedCharacters], range: markerRange, changeInLength: -markerRange.length)
        textView.didChangeText()
        return length - markerLength
    }

    public func withIndentationLevel(indentationLevel: Int) -> ListBlock {
        return ListBlock(
            owner: blockStorage,
            type: .list,
            style: listStyle(forIndentationLevel: indentationLevel),
            range: range,
            index: index,
            indentationLevel: indentationLevel,
            markerLength: markerLength,
            markerString: markerString(forIndentationLevel: indentationLevel)
        )
    }

    public func withRange(_ range: NSRange, index: Int) -> ListBlock {
        return ListBlock(
            owner: blockStorage,
            type: .list,
            style: style,
            range: range,
            index: index,
            indentationLevel: indentationLevel,
            markerLength: 0,
            markerString: markerString(forIndentationLevel: indentationLevel)
        )
    }

    override func createBlocks(for range: NSRange, atIndex blockIndex: Int, startingOffset blockOffset: Int) {
        var offset = blockOffset
        var index = blockIndex

        if range.length == 0 {
            let listRange = NSRange(location: offset, length: 0)
            let listBlock = self.withRange(listRange, index: index)
            blockStorage.insertBlock(listBlock, at: index)
            return
        }

        let string = blockStorage.mutableString
        var lineRanges: [NSRange] = []
        var blocks: [Block] = []

        string.enumerateSubstrings(in: range, options: [.byLines, .substringNotRequired]) {_, _, lineRange, _ in
            lineRanges.append(lineRange)
        }

        for lineRange in lineRanges {
            let listRange = NSRange(location: offset, length: lineRange.length)
            let listBlock = self.withRange(listRange, index: index)
            listBlock.applyStyles(withUndo: true)
            blocks.append(listBlock)

            offset += listBlock.length
            index += 1
        }

        blockStorage.insertBlocks(contentsOf: blocks, at: blockIndex)
        
        if let lastBlock = blocks.last {
            blockStorage.textView.addDeferredCommand(DeferredSelectionCommand(selection: NSRange(location: lastBlock.range.upperBound - 1, length: 0)))
        }
    }

    /// Replace the block with a new block with the given indentation level.
    ///
    /// If the new indentation level is less than zero, converts the block into a TextBlock.
    /// If the new indentation level exceeds the max indentation level, no action is taken.
    private func trySetIndentationLevel(_ newIndentationLevel: Int) {
        if newIndentationLevel > maxIndentationLevel {
            NSSound.beep()
            return
        }

        let textView = blockStorage.textView!
        textView.breakUndoCoalescing()
        
        if newIndentationLevel < 0 {
            textView.beginEditing()
            let converted = TextBlock(owner: blockStorage, range: willConvert(), index: self.index)
            converted.applyStyles(withUndo: true)
            textView.endEditing()

            blockStorage.replaceBlock(at: index, with: converted)
            textView.setSelectedRange(NSRange(location: converted.offset, length: 0))
            textView.typingAttributes = converted.style.attributes
        } else {
            textView.beginEditing()
            let indented = self.withIndentationLevel(indentationLevel: newIndentationLevel)
            blockStorage.replaceBlock(at: index, with: indented)
            textView.endEditing()
        }
    }

    /// Indent when tabbing at the start of a list.
    override func insertTab(at index: Int) -> Bool {
        if index > markerLength {
            return false
        }

        trySetIndentationLevel(indentationLevel + 1)
        return true
    }

    /// Unindent when shift + tabbing at the start of a list.
    override func insertBacktab(at index: Int) -> Bool {
        if index > markerLength {
            return false
        }

        trySetIndentationLevel(indentationLevel - 1)
        return true
    }

    /// Unindent when deleting at the start of a list.
    override func deleteBackward(at index: Int) -> Bool {
        if index > markerLength {
            return false
        }

        trySetIndentationLevel(indentationLevel - 1)
        return true
    }

    /// Unindent when a newline is inserted into an empty list.
    override func insertNewline(at: Int) -> Bool {
        if length != markerLength {
            return false
        }

        trySetIndentationLevel(indentationLevel - 1)
        return true
    }

    override func canExtendSelection(_ range: NSRange, inDirection direction: NSSelectionAffinity) -> Bool {
        if direction == .upstream {
            return range.location > (offset + markerLength)
        } else {
            let newlineAdjustment = endsWithNewlineCharacter() ? 1 : 0
            return (range.location + range.length) != (offset + length - newlineAdjustment)
        }
    }

    override func adjustSelection(_ selection: NSRange, inDirection direction: NSSelectionAffinity) -> NSRange? {
        var blockRange = self.range
        blockRange.location += markerLength
        blockRange.length -= markerLength

        if endsWithNewlineCharacter() {
            blockRange.length -= 1
        } else {
            blockRange.length += 1
        }

        if selection.length == 0 {
            if selection.location >= blockRange.location {
                return NSRange(location: min(selection.location, blockRange.upperBound), length: 0)
            } else if direction == .upstream {
                return NSRange(location: blockRange.location, length: selection.length)
            } else {
                return nil
            }
        }

        if let intersection = blockRange.intersection(selection) {
            return intersection
        } else if blockRange.location < selection.location {
            return NSRange(location: blockRange.location, length: 0)
        } else {
            return NSRange(location: blockRange.upperBound, length: 0)
        }
    }
}
