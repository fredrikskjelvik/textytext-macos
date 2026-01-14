//
//  TextBlockStorage.swift
//  LimitlessUI
//

import Cocoa

class BlockLayoutManager : NSLayoutManager {
    public func boundingRect(forBlock block: Block) -> NSRect {
        let glyphs = glyphRange(forCharacterRange: block.range, actualCharacterRange: nil)

        if glyphs.location >= numberOfGlyphs {
            return extraLineFragmentRect
        }

        let topLine = lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
        let bottomLine = lineFragmentRect(forGlyphAt: glyphs.location + glyphs.length - 1, effectiveRange: nil)

        return NSRect(x: topLine.origin.x,
                      y: topLine.origin.y,
                      width: topLine.size.width,
                      height: bottomLine.origin.y + bottomLine.size.height - topLine.origin.y)
    }

    private func fillBackground(forGlyphRange glpyhRange: NSRange, in textContainer: NSTextContainer, origin: NSPoint) {
        enumerateLineFragments(forGlyphRange: glpyhRange) {rect, usedRect, container, range, stop in
            guard textContainer === container, let selected = glpyhRange.intersection(range) else {
                return
            }

            var selectedRect = self.boundingRect(forGlyphRange: selected, in: textContainer)
            selectedRect.origin.x += origin.x
            selectedRect.origin.y += origin.y
            selectedRect.fill()
        }
    }

    override func drawBackground(forGlyphRange fullGlyphRange: NSRange, at origin: NSPoint) {
        let characterRange = characterRange(forGlyphRange: fullGlyphRange, actualGlyphRange: nil)
        let blockStorage = textStorage as! TextBlockStorage
        let textStorage = blockStorage.underlyingTextStorage
        let blockRange = blockStorage.blockRange(for: characterRange)

        let textView = blockStorage.textView!
        let textWidth = textView.frame.size.width - (origin.x * 2)
        let selectedBlocks = textView.selection.selectedBlocks()

        for block in blockStorage.blocks[blockRange] {
            let isSelected = selectedBlocks.contains(block.index)

            if isSelected == false && block.alwaysDrawsBackground == false {
                continue
            }

            var blockRect = boundingRect(forBlock: block)
            blockRect.size.width = textWidth
            blockRect.origin.x += origin.x
            blockRect.origin.y += origin.y

            block.drawBackground(in: blockRect, isSelected: isSelected)
        }

        guard selectedBlocks.isEmpty, let textContainer = textView.textContainer else {
            return
        }

        textStorage.enumerateAttribute(.backgroundColor, in: characterRange, options: [], using: {value, range, stop in
            if let color = value as? NSColor {
                color.setFill()
                let glyphs = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                fillBackground(forGlyphRange: glyphs, in: textContainer, origin: origin)
            }
        })

        NSColor.selectedTextBackgroundColor.setFill()

        for value in textView.selectedRanges {
            let selectedRange = value.rangeValue
            let selectedGlyphs = glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)

            if let fillGlyphs = selectedGlyphs.intersection(fullGlyphRange) {
                fillBackground(forGlyphRange: fillGlyphs, in: textContainer, origin: origin)
            }
        }
    }
}

enum BlockCodingError : Error {
    case invalidData
    case invalidType
}

enum CodedBlock : Codable {
    private enum Keys : CodingKey {
        case type
        case coded
    }

    case text(TextBlock.Coded)
    case header1(Header1Block.Coded)
    case header2(Header2Block.Coded)
    case list(ListBlock.Coded)
    case orderedlist(OrderedListBlock.Coded)
    case image(ImageBlock.Coded)
    case codesnippet(CodeBlock.Coded)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let type = try container.decode(BlocksInfo.Types.self, forKey: .type)

        switch type {
        case .text:
            self = .text(try container.decode(TextBlock.Coded.self, forKey: .coded))

        case .header1:
            self = .header1(try container.decode(Header1Block.Coded.self, forKey: .coded))

        case .header2:
            self = .header2(try container.decode(Header2Block.Coded.self, forKey: .coded))

        case .list:
            self = .list(try container.decode(ListBlock.Coded.self, forKey: .coded))

        case .orderedlist:
            self = .orderedlist(try container.decode(OrderedListBlock.Coded.self, forKey: .coded))

        case .image:
            self = .image(try container.decode(ImageBlock.Coded.self, forKey: .coded))

        case .codesnippet:
            self = .codesnippet(try container.decode(CodeBlock.Coded.self, forKey: .coded))

        default:
            throw BlockCodingError.invalidType
        }
    }

    init(_ block: Block) throws {
        switch block.type {
        case .text:
            self = .text(try TextBlock.Coded(block))

        case .header1:
            self = .header1(try Header1Block.Coded(block))

        case .header2:
            self = .header2(try Header2Block.Coded(block))

        case .list:
            self = .list(try ListBlock.Coded(block))

        case .orderedlist:
            self = .orderedlist(try OrderedListBlock.Coded(block))

        case .image:
            self = .image(try ImageBlock.Coded(block))

        case .codesnippet:
            self = .codesnippet(try CodeBlock.Coded(block))

        default:
            throw BlockCodingError.invalidType
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        switch self {
        case .text(let coded):
            try container.encode(BlocksInfo.Types.text, forKey: .type)
            try container.encode(coded, forKey: .coded)

        case .header1(let coded):
            try container.encode(BlocksInfo.Types.header1, forKey: .type)
            try container.encode(coded, forKey: .coded)

        case .header2(let coded):
            try container.encode(BlocksInfo.Types.header2, forKey: .type)
            try container.encode(coded, forKey: .coded)

        case .list(let coded):
            try container.encode(BlocksInfo.Types.list, forKey: .type)
            try container.encode(coded, forKey: .coded)

        case .orderedlist(let coded):
            try container.encode(BlocksInfo.Types.orderedlist, forKey: .type)
            try container.encode(coded, forKey: .coded)

        case .image(let coded):
            try container.encode(BlocksInfo.Types.image, forKey: .type)
            try container.encode(coded, forKey: .coded)

        case .codesnippet(let coded):
            try container.encode(BlocksInfo.Types.codesnippet, forKey: .type)
            try container.encode(coded, forKey: .coded)
        }
    }
}

enum BlockEdit {
    case insert(NSRange, String)
    case replace(NSRange, String)
    case replaceWithLines(NSRange, String, String.Index)
    case multiBlockEdit(NSRange, String)
    case deleteLastCharacter(NSRange)
}

enum BlockPosition {
    case above
    case below
}

enum InferredBlockType {
    case text
    case header1
    case header2
    case list(Int)
    case orderedList(Int)
    case code
}

fileprivate extension NSTextList.MarkerFormat {
    private func normalized() -> NSTextList.MarkerFormat {
        let string = rawValue

        guard let start = string.firstIndex(of: "{"),
              let end = string[start...].firstIndex(of: "}")  else {
            return NSTextList.MarkerFormat(rawValue: "")
        }

        return NSTextList.MarkerFormat(rawValue: String(string[start...end]))
    }

    var isOrdered: Bool {
        switch normalized() {
        case .lowercaseHexadecimal,
             .uppercaseHexadecimal,
             .octal,
             .lowercaseAlpha,
             .uppercaseAlpha,
             .lowercaseLatin,
             .uppercaseLatin,
             .lowercaseRoman,
             .uppercaseRoman,
             .decimal:
            return true

        default:
            return false
        }
    }
}

fileprivate func removeListMarker(from attributedString: NSAttributedString) -> NSAttributedString? {
    let string = attributedString.string as NSString
    let stringLength = string.length
    let tab = CharacterSet(charactersIn: "\t")

    guard let firstTab = UnicodeScalar(string.character(at: 0)), tab.contains(firstTab) else {
        return nil
    }

    let remainingRange = NSRange(location: 1, length: stringLength - 1)
    let lastTab = string.rangeOfCharacter(from: tab, options: [], range: remainingRange)

    if lastTab.length == 0 {
        return nil
    }

    let location = lastTab.upperBound
    return attributedString.attributedSubstring(from: NSRange(location: location, length: stringLength - location))
}

fileprivate func checkCodeFence(at index: Int, in lines: [String]) -> Range<Int>? {
    if lines[index].starts(with: "```") == false {
        return nil
    }

    let first = index + 1

    for i in first ..< lines.count {
        let line = lines[i]

        if line.starts(with: "```") && line.dropFirst(3).allSatisfy({$0.isWhitespace}) {
            return first ..< i
        }
    }

    return nil
}

func attributedStringWithInlineStyles(fromMarkdown markdown: String) -> NSAttributedString {
    let attributedString = NSMutableAttributedString(string: markdown)
    attributedString.addAttribute(.inlineStyle, value: StyleBuilder.InlineStyles(), range: NSRange(location: 0, length: attributedString.length))

    let inlineStyles: [(StyleBuilder.InlineStyles, String, Int, [Int])] = [
        (.bold, "(\\*\\*)(\\S.*?)(\\*\\*)", 2, [1, 3]),
        (.italic, "(\\*)(\\S.*?)(\\*)", 2, [1, 3]),
        (.code, "(`)([^`]+)(`)", 2, [1, 3])
    ]

    for (style, pattern, textGroup, markdownGroups) in inlineStyles {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            continue
        }

        let stringRange = NSRange(location: 0, length: attributedString.length)
        var deleteRanges: [NSRange] = []

        for match in regex.matches(in: attributedString.string, options: [], range: stringRange) {
            let textRange = match.range(at: textGroup)

            attributedString.enumerateAttribute(.inlineStyle, in: textRange, options: [], using: {(value, range, stop) in
                if let styles = value as? StyleBuilder.InlineStyles {
                    attributedString.addAttribute(.inlineStyle, value: styles.inserting(style), range: range)
                }
            })

            for markdownGroup in markdownGroups {
                deleteRanges.append(match.range(at: markdownGroup))
            }
        }

        for range in deleteRanges.reversed() {
            attributedString.deleteCharacters(in: range)
        }
    }

    return attributedString
}

/// TextBlockStorage - NSTextStorage subclass with block support.
///
/// A TextBlockStorage provides all the string / attribute handling of a NSTextStorage class, but with some additional
/// block metadata. Every character is owned by one, and only one, Block object. That Block object is responsible
/// for edits that happen within it. The Block objects also provide custom styling / text editing behavior for
/// the region of text they own.
class TextBlockStorage : NSTextStorage, NSLayoutManagerDelegate, InlineStylingDelegate, LinkPopupDelegate, BlockMenuDelegate {
    // Implementation Note:
    //
    // Most of our text handling is delegated to this NSTextStorage property.
    //
    // It may seem odd that we're using a NSTextStorage property rather than calling up to super, given that we are
    // a NSTextStorage subclass, but there's a reason for this. NSTextStorage is an abstract class, it doesn't implement the
    // required string handling methods, so we can't call super. The runtime type for the class below is NSConcreteTextStorage,
    // which is a NSTextStorage subclass that AppKit provides us.
    private var storage = NSTextStorage()
    private var deferredLayout: [NSRange] = []

    private(set) public var blocks: [Block] = []
    public unowned var textView: TextView! = nil

    override var string: String {
        return storage.string
    }

    override var mutableString: NSMutableString {
        return storage.mutableString
    }

    public var underlyingTextStorage: NSTextStorage {
        return storage
    }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return storage.attributes(at: location, effectiveRange: range)
    }

    public func printBlocks() {
        let string = storage.mutableString

        var index = 0
        var offset = 0

        print("---------")

        for block in blocks {
            block.offset = offset
            block.index = index

            let blockString = string.substring(with: block.range) as String
            let terminator = blockString.hasSuffix("\n") ? "" : "\n"

            print("\(index): Type: \(block.type), Length: \(blockString.count), Text: \(blockString)", terminator: terminator)

            offset += block.length
            index += 1
        }
    }

    public func registerBlockStateUndoHandler() {
        guard let undoManager = textView?.undoManager else {
            return
        }

        // TODO: Replace with more memory effecient implementation
        let state = blocks.map({($0, $0.length)})

        undoManager.registerUndo(withTarget: self, handler: {blockStorage in
            blockStorage.registerBlockStateUndoHandler()

            let blocksCount = state.count
            var blocks = [Block]()
            
            blocks.reserveCapacity(blocksCount)

            var offset = 0
            var index = 0

            for (block, length) in state {
                block.didUndoOrRedo(offset: offset, length: length, index: index)
                blocks.append(block)
                offset += length
                index += 1
            }

            for block in blockStorage.blocks {
                let blockIndex = block.index

                if blockIndex < 0 || blockIndex >= blocksCount || block !== blocks[blockIndex] {
                    block.didRemove()
                }
            }

            blockStorage.blocks = blocks
        })
    }

    private func didChangeBlock(positioned position: BlockPosition, blockAt index: Int) {
        if index < 0 || index >= blocks.count {
            return
        }

        let block = blocks[index]

        if block.wantsAdjacentBlockUpdates {
            updateBlocks()
            block.didChangeBlock(positioned: position)
        }
    }

    public func appendBlock(_ block: Block) {
        blocks.append(block)
        didChangeBlock(positioned: .below, blockAt: blocks.count - 2)
    }

    public func insertBlock(_ block: Block, at index: Int) {
        blocks.insert(block, at: index)
        didChangeBlock(positioned: .below, blockAt: index - 1)
        didChangeBlock(positioned: .above, blockAt: index + 1)
    }

    public func insertBlocks<C: Collection>(contentsOf collection: C, at index: Int) where C.Element == Block {
        blocks.insert(contentsOf: collection, at: index)
        didChangeBlock(positioned: .below, blockAt: index - 1)
        didChangeBlock(positioned: .above, blockAt: index + collection.count)
    }

    public func removeBlock(at index: Int) {
        let block = blocks.remove(at: index)
        didChangeBlock(positioned: .below, blockAt: index - 1)
        didChangeBlock(positioned: .above, blockAt: index)
        block.didRemove()
    }

    public func removeBlock(range: Range<Int>) {
        if range.isEmpty {
            return
        }

        for block in blocks[range] {
            block.didRemove()
        }

        let first = range.lowerBound

        blocks.removeSubrange(range)
        didChangeBlock(positioned: .below, blockAt: first - 1)
        didChangeBlock(positioned: .above, blockAt: first)
    }

    public func removeBlocks(range: Range<Int>) {
        for block in blocks[range] {
            block.didRemove()
        }

        let first = range.lowerBound

        blocks.removeSubrange(range)
        didChangeBlock(positioned: .below, blockAt: first - 1)
        didChangeBlock(positioned: .above, blockAt: first)
    }

    public func replaceBlock(at index: Int, with block: Block) {
        blocks[index].didRemove()
        blocks[index] = block

        didChangeBlock(positioned: .below, blockAt: index - 1)
        didChangeBlock(positioned: .above, blockAt: index + 1)
    }

    public func replaceBlocks<C: Collection>(range: Range<Int>, with newBlocks: C) where C.Element == Block {
        for block in blocks[range] {
            block.didRemove()
        }

        blocks.replaceSubrange(range, with: newBlocks)
        didChangeBlock(positioned: .below, blockAt: range.lowerBound - 1)
        didChangeBlock(positioned: .above, blockAt: range.upperBound)
    }

    /// Returns the block immediately after the given block. Or nil if block is the last block.
    ///
    /// This method should be used rather than indexing into the blocks array to ensure the returned
    /// block has the correct index and offset values.
    public func block(after: Block) -> Block? {
        let index = after.index + 1

        if index < blocks.count {
            let next = blocks[index]
            next.index = index
            next.offset = after.offset + after.length
            return next
        }

        return nil
    }

    public func block(atIndex: Int) -> Block {
        var index = 0
        var offset = 0

        for block in blocks {
            if index == atIndex {
                return block
            }

            index += 1
            offset += block.length
        }

        fatalError("Index out of bounds")
    }

    /// Returns the block that owns the character at the given index.
    public func block(at character: Int) -> Block {
        var index = 0
        var offset = 0

        for block in blocks {
            let nextOffset = offset + block.length

            if nextOffset > character {
                block.offset = offset
                block.index = index
                return block
            }

            index += 1
            offset = nextOffset
        }

        if let last = blocks.last {
            last.offset = offset - last.length
            last.index = blocks.count - 1
            return last
        } else {
            let first = TextBlock(owner: self, range: NSRange())
            blocks.append(first)
            return first
        }
    }

    private func createBlock(from codedBlock: CodedBlock, characterOffset: Int, blockIndex: Int) throws -> Block {
        switch codedBlock {
        case .text(let coded):
            return try TextBlock(from: coded, owner: self, offset: characterOffset, index: blockIndex)

        case .header1(let coded):
            return try Header1Block(from: coded, owner: self, offset: characterOffset, index: blockIndex)

        case .header2(let coded):
            return try Header2Block(from: coded, owner: self, offset: characterOffset, index: blockIndex)

        case .list(let coded):
            return try ListBlock(from: coded, owner: self, offset: characterOffset, index: blockIndex)

        case .orderedlist(let coded):
            return try OrderedListBlock(from: coded, owner: self, offset: characterOffset, index: blockIndex)

        case .image(let coded):
            return try ImageBlock(from: coded, owner: self, offset: characterOffset, index: blockIndex)

        case .codesnippet(let coded):
            return try CodeBlock(from: coded, owner: self, offset: characterOffset, index: blockIndex)
        }
    }

    public func createBlocks(from codedBlocks: [CodedBlock], characterOffset: Int,  blockIndex: Int) -> Range<Int> {
        var offset = characterOffset
        var index = blockIndex

        if blockIndex == blocks.count {
            appendTextBlock()
            offset += 1
        }

        for coded in codedBlocks {
            if let block = try? createBlock(from: coded, characterOffset: offset, blockIndex: index) {
                blocks.insert(block, at: index)
                offset += block.length
                index += 1
            }
        }

        if index != blockIndex {
            didChangeBlock(positioned: .below, blockAt: blockIndex - 1)
            didChangeBlock(positioned: .above, blockAt: index)
        }

        return blockIndex ..< index
    }

    /// Returns the range of blocks that intersect witht the given character range.
    public func blockRange(for range: NSRange) -> Range<Int> {
        let rangeUpperBound = range.upperBound

        let first = block(at: range.location)
        let firstIndex = first.index

        var index = firstIndex + 1
        var offset = first.offset + first.length

        for block in self.blocks.dropFirst(index) {
            if offset >= rangeUpperBound {
                break
            }

            block.offset = offset
            block.index = index
            index += 1
            offset += block.length
        }

        return firstIndex ..< index
    }

    public func updateBlocks() {
        var index = 0
        var offset = 0

        for block in blocks {
            block.index = index
            block.offset = offset
            index += 1
            offset += block.length
        }
    }

    public func updateBlock(_ block: Block) {
        var index = 0
        var offset = 0

        for block in blocks {
            if block === block {
                block.index = index
                block.offset = offset
            }

            index += 1
            offset += block.length
        }
    }

    public func characterOffset(forBlockAt blockIndex: Int) -> Int {
        var offset = 0

        for index in 0 ..< blockIndex {
            offset += blocks[index].length
        }

        return offset
    }

    public func attributedSubstring(fromBlockRange blockRange: Range<Int>) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()

        var textLists: [NSTextList] = []
        var positionStack: [Int] = []
        var lastBlockType = BlocksInfo.Types.text
        var lastIndentationLevel = -1

        for block in blocks[blockRange] {
            let blockType = block.type

            if blockType != lastBlockType {
                textLists.removeAll(keepingCapacity: true)
                positionStack.removeAll(keepingCapacity: true)
                lastIndentationLevel = -1
                lastBlockType = blockType
            }

            if let imageBlock = block as? ImageBlock {
                if let image = imageBlock.image {
                    let attachment = NSTextAttachment()
                    attachment.image = image
                    attributedString.append(NSAttributedString(attachment: attachment))
                    attributedString.append(NSAttributedString(string: "\n"))
                }

                continue
            }

            guard let listBlock = block as? ListBlock else {
                let string = attributedSubstring(from: block.range)
                attributedString.append(string)
                continue
            }

            let indentationLevel = listBlock.indentationLevel
            let position: Int

            if indentationLevel > lastIndentationLevel {
                textLists.append(blockType == .orderedlist ?
                                 NSTextList(markerFormat: NSTextList.MarkerFormat(rawValue: "{decimal}."), options: 0) :
                                 NSTextList(markerFormat: NSTextList.MarkerFormat.circle, options: 0))
                positionStack.append(0)
                position = 0
            } else {
                if indentationLevel < lastIndentationLevel && positionStack.count > 0 {
                    let removeCount = positionStack.count - max(1, indentationLevel)
                    positionStack.removeLast(removeCount)
                    textLists.removeLast(removeCount)
                }

                let lastIndex = positionStack.count - 1
                position = positionStack[lastIndex] + 1
                positionStack[lastIndex] = position
            }

            lastIndentationLevel = indentationLevel

            let adjusted = NSMutableAttributedString()
            let text = attributedSubstring(from: block.textRange)
            let attributes = attributes(at: block.range.location, effectiveRange: nil)

            let marker = NSAttributedString(string: "\t\(textLists.last!.marker(forItemNumber: position + 1))\t", attributes: attributes)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 5.0
            paragraphStyle.textLists = textLists
            paragraphStyle.firstLineHeadIndent = CGFloat(positionStack.count * 28)

            adjusted.append(marker)
            adjusted.append(text)
            adjusted.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: adjusted.length))

            attributedString.append(adjusted)
        }

        if attributedString.string.hasSuffix("\n") == false {
            let attributes = attributedString.attributes(at: attributedString.length - 1, effectiveRange: nil)
            attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
        }

        return attributedString
    }

    public func characterRange(forBlockRange blockRange: Range<Int>) -> NSRange {
        let firstBlock = blocks[blockRange.first!]
        let lastBlock = blocks[blockRange.last!]

        let firstBlockOffset = firstBlock.offset
        let lastBlockUpperbound = lastBlock.range.upperBound

        return NSRange(location: firstBlockOffset, length: lastBlockUpperbound - firstBlockOffset)
    }

    public func deleteBlocks(inRange blockRange: Range<Int>, withCharacterRange characterRange: NSRange) {
        if let textView = self.textView, textView.shouldChangeText(in: characterRange, replacementString: "") {
            removeBlocks(range: blockRange)
            storage.deleteCharacters(in: characterRange)
            edited([.editedAttributes, .editedCharacters], range: characterRange, changeInLength: -characterRange.length)
            textView.didChangeText()
        }
    }

    public func insertBlocks(_ newBlocks: [Block], at blockIndex: Int, contents: NSAttributedString) {
        if blockIndex == blocks.count {
            appendTextBlock()
        }

        var characterIndex = 0

        for block in blocks[0 ..< blockIndex] {
            characterIndex += block.length
        }

        let editedRange = NSRange(location: characterIndex, length: 0)

        if let textView = self.textView, textView.shouldChangeText(in: editedRange, replacementString: contents.string) {
            insertBlocks(contentsOf: newBlocks, at: blockIndex)
            storage.insert(contents, at: characterIndex)
            edited([.editedAttributes, .editedCharacters], range: editedRange, changeInLength: contents.length)
            textView.didChangeText()
        }
    }

    private func createBlocks(at blockIndex: Int, withTypesAndContent lines: [(InferredBlockType, NSAttributedString)]) {
        let isAppending = blockIndex == blocks.count
        let lastIndex = blockIndex + lines.count - 1

        var index = blockIndex
        var indentDelta = 0
        var offset: Int

        if blockIndex == 0 {
            offset = 0
        } else {
            let blockBefore = blocks[blockIndex - 1]
            updateBlock(blockBefore)

            let blockEnd = blockBefore.range.upperBound
            replaceCharactersWithUndo(in: NSRange(location: blockEnd, length: 0), with: "\n")
            blockBefore.length += 1
            offset = blockEnd + 1

            blockBefore.applyStyles()
        }

        for (blockType, content) in lines {
            var lineLength = content.length
            replaceCharactersWithUndo(in: NSRange(location: offset, length: 0), with: content)

            if isAppending == false || index != lastIndex {
                replaceCharactersWithUndo(in: NSRange(location: offset + lineLength, length: 0), with: "\n")
                lineLength += 1
            }

            let blockRange = NSRange(location: offset, length: lineLength)
            let block: Block

            switch blockType {
            case .text:
                block = TextBlock(owner: self, range: blockRange, index: index)
                indentDelta = 0

            case .header1:
                block = Header1Block(owner: self, range: blockRange, index: index)
                indentDelta = 0

            case .header2:
                block = Header2Block(owner: self, range: blockRange, index: index)
                indentDelta = 0

            case .list(let indentationLevel):
                block = ListBlock(owner: self, range: blockRange, index: index, indentationLevel: indentationLevel)
                indentDelta = 0

            case .orderedList(let indentationLevel):
                let desiredIndent = indentationLevel + indentDelta
                let orderedListBlock = OrderedListBlock(owner: self, range: blockRange, index: index, desiredIndentationLevel: desiredIndent)
                indentDelta = orderedListBlock.indentationLevel - indentationLevel
                block = orderedListBlock

            case .code:
                let isLast = isAppending && index == lastIndex
                block = CodeBlock(owner: self, range: blockRange, index: index, isLast: isLast)
                indentDelta = 0

                if isLast {
                    textView.deferredSelection = NSRange(location: blockRange.upperBound - 1, length: 0)
                }
            }

            block.applyStyles()
            blocks.insert(block, at: index)

            offset = block.range.upperBound
            index += 1
        }

        didChangeBlock(positioned: .below, blockAt: blockIndex - 1)
        didChangeBlock(positioned: .above, blockAt: blockIndex + (index - blockIndex))
    }

    public func createBlocks(at blockIndex: Int, withMarkdown lines: [String]) {
        let headerRegex = try! NSRegularExpression(pattern: "^#\\s*?")
        let subheaderRegex = try! NSRegularExpression(pattern: "^##\\s*?")
        let listRegex = try! NSRegularExpression(pattern: "^(\\s*?)(\\*|-) ")
        let orderedListRegex = try! NSRegularExpression(pattern: "^(\\s*?)(\\d+)\\. ")

        var typeAndContent: [(InferredBlockType, NSAttributedString)] = []
        let linesCount = lines.count
        var index = 0

        while index < linesCount {
            if let codeFenceRange = checkCodeFence(at: index, in: lines) {
                typeAndContent.append((.code, NSAttributedString(string: lines[codeFenceRange].joined(separator: "\n"))))
                index = codeFenceRange.upperBound + 1
                continue
            }

            let line = lines[index]
            let lineUTF16 = line.utf16
            let lineRange = NSRange(location: 0, length: lineUTF16.count)

            func match(regex: NSRegularExpression) -> (NSTextCheckingResult, NSAttributedString)? {
                if let match = regex.firstMatch(in: line, options: [], range: lineRange) {
                    let matchRange = match.range

                    if matchRange.length < lineRange.length {
                        let withoutMatch = String(lineUTF16.dropFirst(matchRange.length))!
                        let attributedString = attributedStringWithInlineStyles(fromMarkdown: withoutMatch)
                        return (match, attributedString)
                    }
                }

                return nil
            }

            if let (_, content) = match(regex: subheaderRegex) {
                typeAndContent.append((.header2, content))
            } else if let (_, content) = match(regex: headerRegex) {
                typeAndContent.append((.header1, content))
            } else if let (match, content) = match(regex: listRegex) {
                typeAndContent.append((.list(match.range(at: 1).length), content))
            } else if let (match, content) = match(regex: orderedListRegex) {
                typeAndContent.append((.orderedList(match.range(at: 1).length), content))
            } else {
                typeAndContent.append((.text, attributedStringWithInlineStyles(fromMarkdown: line)))
            }

            index += 1
        }

        createBlocks(at: blockIndex, withTypesAndContent: typeAndContent)
    }

    public func createBlocks(at blockIndex: Int, withLines lines: [NSAttributedString]) {
        let typeAndContent = lines.map({(attributedString) -> (InferredBlockType, NSAttributedString) in
            if attributedString.length == 0 {
                return (.text, attributedString)
            }

            let attributes = attributedString.attributes(at: 0, effectiveRange: nil)

            if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
                let lists = paragraphStyle.textLists

                if let last = lists.last, let withoutMarker = removeListMarker(from: attributedString) {
                    let indentationLevel = lists.count - 1

                    if last.markerFormat.isOrdered {
                        return (.orderedList(indentationLevel), withoutMarker)
                    } else {
                        return (.list(indentationLevel), withoutMarker)
                    }
                }
            }

            if let font = attributes[.font] as? NSFont {
                let pointSize = font.pointSize

                if pointSize > 20 {
                    return (.header1, attributedString)
                } else if pointSize > 14 {
                    return (.header2, attributedString)
                }
            }

            return (.text, attributedString)
        })

        createBlocks(at: blockIndex, withTypesAndContent: typeAndContent)
    }

    private func createBlock(type: BlocksInfo.Types, with range: NSRange, at index: Int) -> Block {
        switch type {
        case .text:
            return TextBlock(owner: self, range: range, index: index)

        case .header1:
            return Header1Block(owner: self, range: range, index: index)

        case .header2:
            return Header2Block(owner: self, range: range, index: index)

        case .list:
            return ListBlock(owner: self, range: range, index: index)

        case .orderedlist:
            return OrderedListBlock(owner: self, range: range, index: index)

        case .codesnippet:
            return CodeBlock(owner: self, range: range, index: index)

        case .image:
            return ImageBlock(owner: self, range: range, index: index)

        default:
            fatalError("Unsupported block type!")
        }
    }

    @discardableResult public func createBlock(at index: Int, ofType blockType: BlocksInfo.Types) -> Block {
        let replaceRange: NSRange
        let insertedRange: NSRange

        if index == 0 {
            replaceRange = NSRange()
        } else {
            let blockBefore = blocks[index - 1]
            let blockBeforeRange = blockBefore.range
            replaceRange = NSRange(location: blockBeforeRange.upperBound, length: 0)
        }

        if index != blocks.count {
            insertedRange = NSRange(location: replaceRange.location, length: 1)
        } else {
            insertedRange = NSRange(location: replaceRange.location + 1, length: 0)

            if let lastBlock = blocks.last {
                lastBlock.length += 1
            }
        }

        let textView = self.textView!
        textView.shouldChangeText(in: replaceRange, replacementString: "\n")
        storage.replaceCharacters(in: replaceRange, with: "\n")
        edited([.editedCharacters], range: replaceRange, changeInLength: 1)
        textView.didChangeText()

        let newBlock = createBlock(type: blockType, with: insertedRange, at: index)
        insertBlock(newBlock, at: index)

        return newBlock
    }

    public func appendTextBlock() {
        createBlock(at: blocks.count, ofType: .text)
    }

    private func isUndoingOrRedoing() -> Bool {
        if let undoManager = textView?.undoManager {
            return undoManager.isUndoing || undoManager.isRedoing
        } else {
            return false
        }
    }

    override func replaceCharacters(in range: NSRange, with string: String) {
        storage.replaceCharacters(in: range, with: string)
        edited([.editedCharacters], range: range, changeInLength: string.utf16.count - range.length)
    }

    override func replaceCharacters(in range: NSRange, with string: NSAttributedString) {
        let fullRange = NSRange(location: 0, length: string.length)
        let adjusted = NSMutableAttributedString(attributedString: string)

        string.enumerateAttributes(in: fullRange, options: [], using: {attributes, range, stop in
            var styles: StyleBuilder.InlineStyles = []

            if let underlineStyle = attributes[.underlineStyle] as? Int, underlineStyle != 0 {
                styles.insert(.underline)
            }

            if let font = attributes[.font] as? NSFont {
                let descriptor = font.fontDescriptor
                let traits = descriptor.symbolicTraits

                if traits.contains(.bold) {
                    styles.insert(.bold)
                }

                if traits.contains(.italic) {
                    styles.insert(.italic)
                }

                if font.isFixedPitch {
                    styles.insert(.code)
                }
            }

            if styles.isEmpty == false {
                adjusted.addAttribute(.inlineStyle, value: styles, range: range)
            }
        })

        storage.replaceCharacters(in: range, with: adjusted)
        edited([.editedCharacters, .editedAttributes], range: range, changeInLength: string.length - range.length)
    }

    func replaceCharactersWithUndo(in range: NSRange, with string: String) {
        let textView = self.textView!
        textView.shouldChangeText(in: range, replacementString: string)
        replaceCharacters(in: range, with: string)
        textView.didChangeText()
    }

    func replaceCharactersWithUndo(in range: NSRange, with string: NSAttributedString) {
        let textView = self.textView!
        textView.shouldChangeText(in: range, replacementString: string.string)
        replaceCharacters(in: range, with: string)
        textView.didChangeText()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        storage.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
    }

    func inlineStyling(toggleStyle style: StyleBuilder.InlineStyles, forCharacters range: NSRange, inBlockRange blockRange: Range<Int>) {
        let textView = self.textView!

        textView.beginEditing()
        textView.shouldChangeText(in: range, replacementString: nil)

        for block in blocks[blockRange] {
            if let toggleRange = range.intersection(block.range) {
                block.toggleStyle(style, in: toggleRange)
            }
        }

        edited([.editedAttributes], range: range, changeInLength: 0)

        textView.didChangeText()
        textView.endEditing()
    }

    private func singleLineBlock(from range: NSRange, startIndex: Int, index: Int, type: BlocksInfo.Types) -> Block {
        switch type {
        case .text:
            return TextBlock(owner: self, range: range, index: index)

        case .header1:
             return Header1Block(owner: self, range: range, index: index)

        case .header2:
            return Header2Block(owner: self, range: range, index: index)

        case .list:
            return ListBlock(owner: self, range: range, index: index)

        case .orderedlist:
            return OrderedListBlock(owner: self, range: range, index: index, position: index - startIndex)

        default:
            fatalError("Unimplemented block type")
        }
    }

    private func convertBlocks(in blockRange: Range<Int>, toSingleLineBlocks blockType: BlocksInfo.Types) {
        let string = storage.mutableString
        let oldBlocks = blocks[blockRange]
        var newBlocks = [Block]()

        let startIndex = blockRange.lowerBound
        var index = startIndex
        var offsetAdjustments = 0

        for block in oldBlocks {
            block.offset += offsetAdjustments

            let blockLength = block.length
            let convertRange = block.willConvert()

            if block.isSingleLine {
                let block = singleLineBlock(from: convertRange, startIndex: startIndex, index: index, type: blockType)
                newBlocks.append(block)
                offsetAdjustments += (block.length - blockLength)
                index += 1
            } else {
                offsetAdjustments += (convertRange.length - blockLength)

                string.enumerateSubstrings(in: convertRange, options: [.byLines, .substringNotRequired]) {[self] _, _, lineRange, _ in
                    let block = singleLineBlock(from: lineRange, startIndex: startIndex, index: index, type: blockType)
                    newBlocks.append(block)
                    offsetAdjustments += (block.length - lineRange.length)
                    index += 1
                }
            }
        }

        replaceBlocks(range: blockRange, with: newBlocks)

        for block in newBlocks {
            block.applyStyles(withUndo: true)
        }
    }

    private func convertBlocks(in blockRange: Range<Int>, toMultiLineBlock blockType: BlocksInfo.Types) {
        let replaceBlocks = blocks[blockRange]
        let initialIndex = blockRange.first!
        let initialOffset = replaceBlocks.first!.offset

        var offsetAdjustments = 0
        var totalLength = 0

        for block in replaceBlocks {
            block.offset += offsetAdjustments

            let blockLength = block.length
            let convertRange = block.willConvert()

            offsetAdjustments += (convertRange.length - blockLength)
            totalLength += convertRange.length
        }

        removeBlocks(range: blockRange)
        let convertRange = NSRange(location: initialOffset, length: totalLength)
        let converted: Block

        switch blockType {
        case .codesnippet:
            converted = CodeBlock(owner: self, range: convertRange, index: initialIndex)

        default:
            fatalError("Unsupported block type")
        }

        insertBlock(converted, at: initialIndex)
        converted.applyStyles(withUndo: true)
    }

    func inlineStyling(setBlockType blockType: BlocksInfo.Types, forBlocks blockRange: Range<Int>) {
        let textView = self.textView!
        textView.breakUndoCoalescing()
        textView.beginEditing()

        if blockType.isSingleLine() {
            convertBlocks(in: blockRange, toSingleLineBlocks: blockType)
        } else {
            convertBlocks(in: blockRange, toMultiLineBlock: blockType)
        }

        textView.endEditing()
        textView.needsDisplay = true
    }

    func inlineStyling(editLinkAt linkRange: NSRange, url: URL?) {
        let text = storage.mutableString.substring(with: linkRange)
        textView.displayLinkPopup(for: linkRange, text: text, url: url)
    }

    func inlineStyling(removeLinkAt linkRange: NSRange) {
        textView.beginEditing()
        storage.removeAttribute(.link, range: linkRange)
        edited([.editedAttributes], range: linkRange, changeInLength: 0)
        textView.endEditing()
    }

    func linkPopup(createLinkAt range: NSRange, withText text: String, linkingTo url: URL) {
        let textView = self.textView!
        let attrRange = NSRange(location: range.location, length: text.utf16.count)
        let changeInLength = attrRange.length - range.length

        textView.breakUndoCoalescing()
        textView.beginEditing()

        textView.shouldChangeText(in: range, replacementString: text)
        storage.replaceCharacters(in: range, with: text)
        edited([.editedCharacters], range: range, changeInLength: changeInLength)
        textView.didChangeText()

        textView.shouldChangeText(in: attrRange, replacementString: nil)
        storage.addAttribute(.link, value: url, range: attrRange)
        edited([.editedAttributes], range: attrRange, changeInLength: 0)
        textView.didChangeText()

        let block = block(at: range.location)
        block.length += (attrRange.length - range.length)

        textView.endEditing()
    }

    func blockMenu(commandRange: NSRange, in block: Block, createBlockOfType blockType: BlocksInfo.Types) {
        let textView = self.textView!
        let blockIndex = block.index
        let blockRange = block.range

        let emptyLength = block.endsWithNewlineCharacter() ? 1 : 0
        let newBlockLength = blockRange.length - commandRange.length

        textView.beginEditing()
        textView.shouldChangeText(in: commandRange, replacementString: "")
        replaceCharacters(in: commandRange, with: "")
        textView.didChangeText()

        let newBlock: Block

        if newBlockLength == emptyLength {
            blocks.remove(at: blockIndex)
            newBlock = createBlock(type: blockType, with: NSRange(location: blockRange.location, length: newBlockLength), at: blockIndex)
            insertBlock(newBlock, at: blockIndex)
        } else {
            block.length = newBlockLength
            newBlock = createBlock(at: blockIndex + 1, ofType: blockType)
        }

        newBlock.applyStyles()

        textView.endEditing()
        textView.setSelectedRange(NSRange(location: newBlock.textRange.location, length: 0), in: newBlock.index)
        textView.typingAttributes = newBlock.style.attributes
    }

    public func layoutDeferred() {
        if deferredLayout.isEmpty {
            return
        }

        let storageLength = storage.length

        for range in deferredLayout {
            if range.location >= storageLength {
                continue
            }

            let adjustedLength = min(range.length, storageLength - range.location)
            let adjustedRange = NSRange(location: range.location, length: adjustedLength)

            for layoutManager in layoutManagers {
                layoutManager.invalidateLayout(forCharacterRange: adjustedRange, actualCharacterRange: nil)
            }
        }

        deferredLayout.removeAll(keepingCapacity: true)
    }

    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>,
                       lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
                       baselineOffset: UnsafeMutablePointer<CGFloat>,
                       in textContainer: NSTextContainer,
                       forGlyphRange glyphRange: NSRange) -> Bool {
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let blockRange = blockRange(for: characterRange)
        let textView = self.textView!

        for block in blocks[blockRange] {
            if block.adjustsLayout == false {
                continue
            }

            if textView.editCount != 0 {
                deferredLayout.append(characterRange)
                return false
            }

            return block.adjustLayout(layoutManager: layoutManager,
                                      lineFragmentRect: lineFragmentRect,
                                      lineFragmentUsedRect: lineFragmentUsedRect,
                                      baselineOffset: baselineOffset,
                                      characterRange: characterRange)
        }

        return false
    }
}
