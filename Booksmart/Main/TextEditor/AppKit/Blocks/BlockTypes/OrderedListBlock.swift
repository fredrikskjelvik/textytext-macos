import Cocoa

/// Indentation from the start of the line to the bullet.
fileprivate let bulletIndentLevel: CGFloat = 40

/// Indentation from after the bullet to the start of text.
fileprivate let textIndentLevel: CGFloat = 10

/// The amount nested lists are incremented by.
fileprivate let indentIncrement: CGFloat = 40

fileprivate func orderedListStyle(forIndentationLevel indentationLevel: Int) -> StyleBuilder {
    let bulletPosition = bulletIndentLevel + (indentIncrement * CGFloat(indentationLevel))
    let textPosition = bulletPosition + textIndentLevel

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacing = 5.0
    paragraphStyle.tabStops = [NSTextTab(type: .rightTabStopType, location: bulletPosition), NSTextTab(type: .leftTabStopType, location: textPosition)]
    paragraphStyle.defaultTabInterval = 28
    paragraphStyle.headIndent = textPosition

    let attributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.Monochrome.RegularBlack,
        .font: NSFont.systemFont(ofSize: 18.0),
        .paragraphStyle: paragraphStyle,
        .blockType: BlocksInfo.Types.orderedlist,
        .inlineStyle: StyleBuilder.InlineStyles.none
    ]

    return StyleBuilder(attributes: attributes)
}

fileprivate func decimalMarker(forPosition position: Int) -> String {
    return "\t" + String(position + 1) + ".\t"
}

fileprivate func alphabetMarker(forPosition position: Int) -> String {
    let character = Character(Unicode.Scalar(UInt8(97) + UInt8(position % 26)))
    let marker = String(repeating: character, count: 1 + (position / 26))
    return "\t" + marker + ".\t"
}

fileprivate func romanNumeralMarker(forPosition position: Int) -> String {
    var position = position + 1
    var numerals = String()

    for (letter, value) in [("m", 1000), ("d", 500), ("c", 100), ("l", 50), ("x", 10), ("v", 5), ("i", 1)] {
        if position < value {
            continue
        }

        let count = position / value
        position = position % value

        for _ in 0..<count {
            numerals.append(letter)
        }

        if position == 0 {
            break
        }
    }

    return "\t" + numerals + ".\t"
}

fileprivate func markerString(forPosition position: Int, atIndentationLevel indentationLevel: Int) -> String {
    switch indentationLevel {
    case 0:
        return decimalMarker(forPosition: position)

    case 1:
        return alphabetMarker(forPosition: position)

    case 2:
        return romanNumeralMarker(forPosition: position)

    default:
        fatalError("Invalid indentation level")
    }
}

fileprivate func listPosition(decimalMarker marker: String) -> Int {
    if let position = Int(marker) {
        return position - 1
    }

    return 0
}

fileprivate func listPosition(alphabetMarker marker: String) -> Int {
    if marker.isEmpty == false, let character = marker[marker.startIndex].asciiValue {
        return ((marker.count - 1) * 26) + (Int(character) - 97)
    }

    return 0
}

fileprivate func listPosition(romanNumeralMarker marker: String) -> Int {
    var position = 0

    for letter in marker {
        switch letter {
        case "i": position += 1
        case "v": position += 5
        case "x": position += 10
        case "l": position += 50
        case "c": position += 100
        case "d": position += 500
        case "m": position += 1000
        default:  continue
        }
    }

    return max(position - 1, 0)
}

fileprivate func listPosition(marker: String, atIndentationLevel indentationLevel: Int) -> Int {
    switch indentationLevel {
    case 0:
        return listPosition(decimalMarker: marker)

    case 1:
        return listPosition(alphabetMarker: marker)

    case 2:
        return listPosition(romanNumeralMarker: marker)

    default:
        fatalError("Invalid indentation level")
    }
}

fileprivate func listPositionForNewBlock(at index: Int, indentationLevel: Int, characterOffset: Int, in blockStorage: TextBlockStorage) -> Int {
    if index > blockStorage.blocks.count {
        return 0
    }

    var index = index
    var offsets = 0

    while index > 0 {
        index -= 1

        guard let block = blockStorage.blocks[index] as? OrderedListBlock, block.indentationLevel >= indentationLevel else {
            break
        }

        offsets += block.length

        if block.indentationLevel == indentationLevel {
            block.index = index
            block.offset = characterOffset - offsets
            return block.position + 1
        }
    }

    return 0
}

fileprivate func maxIndentationLevelForNewBlock(at index: Int, in owner: TextBlockStorage) -> Int {
    let above = index - 1

    if above < 0 || above >= owner.blocks.count {
        return 0
    }

    if let block = owner.blocks[above] as? OrderedListBlock {
        return min(block.indentationLevel + 1, 2)
    } else {
        return 0
    }
}

class OrderedListBlock: ListBlock {
    convenience init(owner: TextBlockStorage, range: NSRange, index: Int, position: Int, indentationLevel: Int = 0) {
        self.init(
            owner: owner,
            type: .orderedlist,
            style: orderedListStyle(forIndentationLevel: indentationLevel),
            range: range,
            index: index,
            indentationLevel: indentationLevel,
            markerLength: 0,
            markerString: markerString(forPosition: position, atIndentationLevel: indentationLevel)
        )
    }

    convenience init(owner: TextBlockStorage, range: NSRange, index: Int, desiredIndentationLevel: Int) {
        let maxIndent = maxIndentationLevelForNewBlock(at: index, in: owner)
        let indentationLevel = min(desiredIndentationLevel, maxIndent)
        let position = listPositionForNewBlock(at: index, indentationLevel: indentationLevel, characterOffset: range.location, in: owner)
        self.init(owner: owner, range: range, index: index, position: position, indentationLevel: indentationLevel)
    }

    convenience init(owner: TextBlockStorage, range: NSRange, index: Int = 0) {
        self.init(owner: owner, range: range, index: index, position: 0, indentationLevel: 0)
    }

    convenience init(from coded: Coded, owner: TextBlockStorage, offset: Int, index: Int) throws {        
        let string = NSMutableAttributedString(string: coded.string)

        let maxIndent = maxIndentationLevelForNewBlock(at: index, in: owner)
        let adjustedIndent = min(coded.indentationLevel, maxIndent)
        let position = listPositionForNewBlock(at: index, indentationLevel: adjustedIndent, characterOffset: offset, in: owner)
        let style = orderedListStyle(forIndentationLevel: adjustedIndent)

        let marker = markerString(forPosition: position, atIndentationLevel: adjustedIndent)
        let content = NSMutableAttributedString(string: marker, attributes: style.attributes)

        string.addAttribute(.paragraphStyle, value: style.attributes[.paragraphStyle]!, range: NSRange(location: 0, length: string.length))
        content.append(string)

        let textView = owner.textView!
        let replaceRange = NSRange(location: offset, length: 0)
        let range = NSRange(location: offset, length: content.length)

        textView.shouldChangeText(in: replaceRange, replacementString: content.string)
        owner.underlyingTextStorage.insert(content, at: offset)
        owner.edited([.editedCharacters, .editedAttributes], range: replaceRange, changeInLength: range.length)
        textView.didChangeText()

        self.init(owner: owner, type: .orderedlist, style: style, range: range, index: index, indentationLevel: adjustedIndent, markerLength: marker.utf16.count, markerString: nil)
        
        for style in coded.inlineStyles {
            var range = toParentRange(blockRange: style.range)
                range = NSRange(location: range.location + self.markerLength, length: range.length)
            textView.shouldChangeText(in: range, replacementString: nil)
            textStorage.addAttributes(style.attributes, range: range)
            blockStorage.edited([.editedAttributes], range: range, changeInLength: 0)
            textView.didChangeText()
        }

        applyStyles()
    }
    
    struct Coded: Codable, StringBasedBlockCoded {
        let indentationLevel: Int
        let markerLength: Int
        let string: String
        let inlineStyles: [StyleBuilder.Coded]

        init(_ block: Block) throws {
            guard let listBlock = block as? OrderedListBlock else {
                throw BlockCodingError.invalidType
            }
            
            func rangeAdjustedByMarkerLength(_ range: NSRange) -> NSRange {
                return NSRange(location: range.location + listBlock.markerLength, length: range.length - listBlock.markerLength)
            }
            
            let attributed = block.textStorage.attributedSubstring(from: rangeAdjustedByMarkerLength(block.range))
            self.string = attributed.string
            self.markerLength = listBlock.markerLength
            self.indentationLevel = listBlock.indentationLevel
            
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

                if attributes.isEmpty == false
                {
                    inlineStyles.append(StyleBuilder.Coded(range: range, attributes: attributes))
                }
            })
            
            self.inlineStyles = inlineStyles
        }
    }

    override var wantsAdjacentBlockUpdates: Bool {
        return true
    }

    private func blockAbove() -> OrderedListBlock? {
        let index = self.index

        if index > 0 && index < blockStorage.blocks.count && blockStorage.blocks[index] === self {
            return blockStorage.blocks[index - 1] as? OrderedListBlock
        }

        return nil
    }

    override var maxIndentationLevel: Int {
        if let above = blockAbove() {
            return min(above.indentationLevel + 1, 2)
        }

        return 0
    }

    var position: Int {
        let markerLength = self.markerLength

        if markerLength < 4 {
            return 0
        }

        let markerRange = NSRange(location: offset + 1, length: markerLength - 3)
        let marker = textStorage.mutableString.substring(with: markerRange)
        return listPosition(marker: marker, atIndentationLevel: indentationLevel)
    }

    override func withRange(_ range: NSRange, index: Int) -> ListBlock {
        let indexDelta = index - self.index

        return OrderedListBlock(
            owner: blockStorage,
            type: .orderedlist,
            style: style,
            range: range,
            index: index,
            indentationLevel: indentationLevel,
            markerLength: 0,
            markerString: markerString(forPosition: position + indexDelta, atIndentationLevel: indentationLevel)
        )
    }

    private func withPosition(position: Int, indentationLevel: Int) -> OrderedListBlock {
        return OrderedListBlock(
            owner: blockStorage,
            type: .orderedlist,
            style: orderedListStyle(forIndentationLevel: indentationLevel),
            range: range,
            index: index,
            indentationLevel: indentationLevel,
            markerLength: markerLength,
            markerString: markerString(forPosition: position, atIndentationLevel: indentationLevel)
        )
    }

    override func withIndentationLevel(indentationLevel: Int) -> ListBlock {
        let newPosition = listPositionForNewBlock(at: index, indentationLevel: indentationLevel, characterOffset: offset, in: blockStorage)
        return withPosition(position: newPosition, indentationLevel: indentationLevel)
    }

    override func createBlocks(for range: NSRange, atIndex blockIndex: Int, startingOffset blockOffset: Int) {
        let oldBlocksCount = blockStorage.blocks.count
        super.createBlocks(for: range, atIndex: blockIndex, startingOffset: blockOffset)

        let createdBlocksCount = blockStorage.blocks.count - oldBlocksCount
        let lastNewBlock = blockStorage.blocks[blockIndex + createdBlocksCount - 1]
        
        let textView = blockStorage.textView!

        textView.addDeferredCommand(DeferredSelectionCommand(selection: NSRange(location: lastNewBlock.range.upperBound - 1, length: 0)))
    }

    private func updatePosition(newPosition: Int) {
        let newMarker = markerString(forPosition: newPosition, atIndentationLevel: indentationLevel)
        let markerLength = self.markerLength

        if markerLength == newMarker.utf16.count {
            let markerRange = NSRange(location: offset, length: markerLength)
            
            if textStorage.mutableString.compare(newMarker, options: .literal, range: markerRange) == .orderedSame {
                return
            }
        }

        placeMarker(markerString: newMarker)
    }

    override func adjacentBlockDidChange(positioned: BlockPosition) {
        var index = self.index
        var offset = blockStorage.characterOffset(forBlockAt: index)

        while index > 0 {
            let previous = index - 1

            if let block = blockStorage.blocks[previous] as? OrderedListBlock {
                index = previous
                offset -= block.length
            } else {
                break
            }
        }

        let textView = blockStorage.textView!
        textView.beginEditing()
        updateMarkers(forListAtIndex: index, atCharacterOffset: offset)
        textView.endEditing()
    }

    private func updateMarkers(forListAtIndex startingIndex: Int, atCharacterOffset startingOffset: Int) {
        let blockCount = blockStorage.blocks.count

        var index = startingIndex
        var indentationLevel = 0
        var maxIndentationLevel = 0
        var length = 0

        var counts = [Int](repeating: 0, count: 3)

        while index < blockCount {
            guard var block = blockStorage.blocks[index] as? OrderedListBlock else {
                return
            }

            block.index = index
            block.offset = startingOffset + length

            let oldIndentationLevel = indentationLevel
            let blockIndentationLevel = block.indentationLevel

            indentationLevel = min(blockIndentationLevel, maxIndentationLevel)

            if indentationLevel > oldIndentationLevel {
                counts[indentationLevel] = 0
            }

            let count = counts[indentationLevel]

            if blockIndentationLevel <= maxIndentationLevel
            {
                block.updatePosition(newPosition: count)
            }
            else
            {
                block = block.withPosition(position: count, indentationLevel: indentationLevel)
                blockStorage.replaceBlock(at: index, with: block)
            }

            maxIndentationLevel = min(indentationLevel + 1, 2)
            counts[indentationLevel] += 1
            length += block.length
            index += 1
        }
    }
}
