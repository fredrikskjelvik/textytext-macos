import Cocoa

class BlockLayoutManager: NSLayoutManager {
    /// Get the NSRect that fully surrounds the block
    ///
    /// The returned rect stretches from the top to bottom boundary of the block (even when it is multi line text, multi paragraph block (e.g. codeblock) or an image) and from
    /// the very left edge to the right edge of the TextView (past the inset)
    /// - Parameter block: Block
    /// - Returns: NSRect surrounding block
    public func getBoundingRect(forBlock block: Block) -> NSRect {
        let glyphRange = glyphRange(forCharacterRange: block.range, actualCharacterRange: nil)

        if glyphRange.location >= numberOfGlyphs {
            return extraLineFragmentRect
        }

        let topLine = lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        let bottomLine = lineFragmentRect(forGlyphAt: glyphRange.location + glyphRange.length - 1, effectiveRange: nil)

        return NSRect(x: topLine.origin.x,
                      y: topLine.origin.y,
                      width: topLine.size.width,
                      height: bottomLine.origin.y + bottomLine.size.height - topLine.origin.y)
    }
    
    /// Given a range of text, .fill() (with e.g. background color) the text. The background fill should be placed according to the line fragment rect. But a glyph range might span
    /// several lines, and also maybe only partial lines. Must only apply fill to the parts intersecting the given glyphRange.
    /// - Parameters:
    ///   - glpyhRange: Some range of text that should be .fill()-ed
    ///   - textContainer: The text container that this should be applied to
    ///   - origin: origin point
    private func fillBackground(forGlyphRange glpyhRange: NSRange, in textContainer: NSTextContainer, origin: NSPoint) {
        // Line fragment means the rectangles where lines of text can be laid out. This loops over those rectangles that intersect
        // with the given glyphrange. I.e. if the glyphrange spans from line 1 to 2, loop over the line fragment rectangles on line
        // one and two.
        enumerateLineFragments(forGlyphRange: glpyhRange) { rect, usedRect, container, range, stop in
            // selected:
            // the range parameter in the closure is the NSRange of the current line fragment. glyphRange is some given
            // NSRange. So selected is the intersection between those. I.e. the part of the glyphRange that is on the current
            // line fragment.
            guard textContainer === container, let selected = glpyhRange.intersection(range) else {
                return
            }

            var selectedRect = self.boundingRect(forGlyphRange: selected, in: textContainer)
            selectedRect.origin.x += origin.x
            selectedRect.origin.y += origin.y
            selectedRect.fill()
        }
    }
    
    /// "Draws background marks for the specified glyphs" This method is called by NSTextView for drawing. You can override it to perform additional drawing.
    ///
    /// It isn't normally called directly.
    /// In this case it is overridden to do the following things:
    /// 1. Draw the background of blocks with their own custom background behavior (e.g. code blocks have a background, and normal blocks have a background
    /// when they are selected
    /// 2. Basically reimplement default behavior that the original method does: Highlighting selected text in light blue and highlighting ranges of text with the property
    /// for highlighted text.
    ///
    /// - Parameters:
    ///   - fullGlyphRange: The range of glyphs for which the background is drawn.
    ///   - origin: The position of the text container in the coordinate system of the currently focused view.
    override func drawBackground(forGlyphRange fullGlyphRange: NSRange, at origin: NSPoint) {
        let characterRange = characterRange(forGlyphRange: fullGlyphRange, actualGlyphRange: nil)
        // we have overridden textStorage with class TextBlockStorage, but layoutmanager doesn't know that.
        let blockStorage = textStorage as! TextBlockStorage
        let textStorage = blockStorage.underlyingTextStorage
        let blockRange = blockStorage.blockRange(for: characterRange)

        let textView = blockStorage.textView!
        let textWidth = textView.frame.size.width - (origin.x * 2)
        let selectedBlocks = textView.selection.selectedBlocks()

        // Loop over the range of blocks that are within fullGlyphRange
        for block in blockStorage.blocks[blockRange] {
            let isSelected = selectedBlocks.contains(block.index)

            // This code is only relevant if
            // 1) The block is selected (then it needs to get a background color
            // 2) It's a special block that needs special background drawing (e.g. codeblock)
            // If not relevant, skip to next block
            if isSelected == false && block.alwaysDrawsBackground == false {
                continue
            }

            // Get the bounding rect for the block, and adjust the size and position
            var blockRect = getBoundingRect(forBlock: block)
                blockRect.size.width = textWidth
                blockRect.origin.x += origin.x
                blockRect.origin.y += origin.y

            // Go to the block's own method to draw its background in its own custom way
            block.drawBackground(in: blockRect, isSelected: isSelected)
        }

        // Don't continue if there are any selected blocks, because the next part is about drawing the background color
        // of text ranges that have the .backgroundColor property (i.e. highlighted text), and this property is not active
        // while in selection mode.
        guard selectedBlocks.isEmpty, let textContainer = textView.textContainer else {
            return
        }

        // Loop over ranges of text that have .backgroundColor property, and draw the background color
        textStorage.enumerateAttribute(.backgroundColor, in: characterRange, options: [], using: {value, range, stop in
            if let color = value as? NSColor {
                color.setFill()
                let glyphs = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                fillBackground(forGlyphRange: glyphs, in: textContainer, origin: origin)
            }
        })

        // Set the color to use in subsequent .fill() calls, namely the default color for selected text (light blue)
        NSColor.selectedTextBackgroundColor.setFill()

        // Loop over selected ranges (actually there's always only one selected range)
        for value in textView.selectedRanges {
            let selectedRange = value.rangeValue
            let selectedGlyphs = glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)

            // Set the background color of the selected text which intersects with the glyph range that NSTextView is
            // currently drawing the background for to the default selected text color light blue.
            if let fillGlyphs = selectedGlyphs.intersection(fullGlyphRange) {
                fillBackground(forGlyphRange: fillGlyphs, in: textContainer, origin: origin)
            }
        }
    }
}
