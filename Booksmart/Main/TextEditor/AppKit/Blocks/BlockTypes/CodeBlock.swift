import Cocoa

fileprivate func blockStyle() -> StyleBuilder {
    let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 28.0
        paragraphStyle.headIndent = 28.0
        paragraphStyle.tailIndent = -28.0
        paragraphStyle.lineSpacing = 4.0
        paragraphStyle.tabStops = [NSTextTab(type: .leftTabStopType, location: 56.0)]
        paragraphStyle.defaultTabInterval = 28.0

    let attributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.Monochrome.RegularBlack,
        .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular),
        .blockType: BlocksInfo.Types.codesnippet,
        .inlineStyle: StyleBuilder.InlineStyles.none
    ]

    return StyleBuilder(attributes: attributes, paragraphStyle: paragraphStyle)
}

class CodeBlock: Block {
    typealias Coded = Block.Coded

    public init(owner: TextBlockStorage, range: NSRange, index: Int = 0, isLast: Bool? = nil) {
        super.init(owner: owner, type: .codesnippet, style: blockStyle(), range: range, index: index)

        if (isLast ?? (index == blockStorage.blocks.count)) {
//            blockStorage.textView.addDeferredCommand(DeferredSelectionCommand(selection: NSRange(location: range.location, length: 0)))
            addTrailingTextBlock()
        }
    }

    public init(from coded: Coded, owner: TextBlockStorage, offset: Int, index: Int) throws {
        try super.init(owner: owner, type: .codesnippet, style: blockStyle(), string: coded.string, inlineStyles: coded.inlineStyles, offset: offset, index: index)
    }
    
    required init(copy block: Block) {
        super.init(copy: block)
    }

    override var isSingleLine: Bool {
        return false
    }

    private func addTrailingTextBlock() {
        let range = NSRange(location: textStorage.length, length: 0)
        let textView = blockStorage.textView!

        length += 1

        textView.shouldChangeText(in: range, replacementString: "\n")
        textStorage.replaceCharacters(in: range, with: "\n")
        blockStorage.edited([.editedCharacters], range: range, changeInLength: 1)
        textView.didChangeText()

        let textBlock = TextBlock(owner: blockStorage, range: NSRange())
        textBlock.applyStyles(withUndo: true)

        blockStorage.appendBlock(textBlock)
    }

    override func willMerge(didDeleteCharacters deletedCount: Int = 0) -> Int {
        let newOffset = offset + deletedCount
        let string = textStorage.mutableString

        var end = 0
        string.getLineStart(nil, end: &end, contentsEnd: nil, for: NSRange(location: newOffset, length: 0))

        let newLength = length - deletedCount
        let mergedLength = end - newOffset

        if mergedLength != newLength {
            length = newLength - mergedLength
            blockStorage.insertBlock(self, at: index)
        }

        return mergedLength
    }

    override func createBlocks(for range: NSRange, atIndex blockIndex: Int, startingOffset blockOffset: Int) {
        if range.location == offset {
            super.createBlocks(for: range, atIndex: blockIndex, startingOffset: blockOffset)
        } else {
            length += range.length
        }
    }

    override func didDeleteLastCharacter() {
        let oldRange = self.range
        super.didDeleteLastCharacter()

        if index == (blockStorage.blocks.count - 1) {
            blockStorage.textView.addDeferredCommand(DeferredSelectionCommand(selection: NSRange(location: oldRange.upperBound - 1, length: 0)))
            addTrailingTextBlock()
        }
    }

    override func _processMarkdown(in inserted: String, at index: Int) {
        applyStyles()
    }

    override var alwaysDrawsBackground: Bool {
        return true
    }

    override func drawBackground(in blockRect: NSRect, isSelected: Bool) {
        let adjustedRect = NSRect(x: blockRect.origin.x,
                                  y: blockRect.origin.y,
                                  width: blockRect.size.width,
                                  height: blockRect.size.height - 4)

        let rectPath = NSBezierPath(roundedRect: adjustedRect, xRadius: 8, yRadius: 8)

        if isSelected {
            NSColor(srgbRed: 212/255, green: 231/255, blue: 238/255, alpha: 1).setFill()
        } else {
            NSColor.Monochrome.LightGray.setFill()
        }

        rectPath.fill()
    }

    override var adjustsLayout: Bool {
        return true
    }

    override func adjustLayout(layoutManager: NSLayoutManager,
                               lineFragmentRect: UnsafeMutablePointer<NSRect>,
                               lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
                               baselineOffset: UnsafeMutablePointer<CGFloat>,
                               characterRange: NSRange) -> Bool {
        let blockRange = self.range

        if characterRange.location == blockRange.location {
            lineFragmentRect.pointee.size.height += 28
            lineFragmentUsedRect.pointee.origin.y += 28
            baselineOffset.pointee += 28
        }

        if (characterRange.location + characterRange.length) == (blockRange.location + blockRange.length) {
            lineFragmentRect.pointee.size.height += 28
        }
        
        return true
    }

    override func insertNewline(at location: Int) -> Bool {
        return false
    }
}
