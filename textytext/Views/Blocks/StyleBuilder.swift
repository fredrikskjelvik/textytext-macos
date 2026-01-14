import Cocoa

struct StyleBuilder {
    /// Inline styles mask. Represents a combination of InlineStyles.
    struct InlineStyles : OptionSet {
        let rawValue: Int

        static let none       = InlineStyles([])
        static let bold       = InlineStyles(rawValue: 1 << 1)
        static let italic     = InlineStyles(rawValue: 1 << 2)
        static let underline  = InlineStyles(rawValue: 1 << 3)
        static let code       = InlineStyles(rawValue: 1 << 4)
        static let highlight  = InlineStyles(rawValue: 1 << 5)

        init(rawValue: Int) {
            self.rawValue = rawValue
        }

        func inserting(_ inlineStyle: InlineStyles) -> InlineStyles {
            var copy = self
            copy.insert(inlineStyle)
            return copy
        }

        func removing(_ inlineStyle: InlineStyles) -> InlineStyles {
            var copy = self
            copy.remove(inlineStyle)
            return copy
        }
    }

    var attributes: [NSAttributedString.Key: Any]

    init(attributes: [NSAttributedString.Key: Any]) {
        self.attributes = attributes
    }

    init(attributes: [NSAttributedString.Key: Any], paragraphStyle: NSMutableParagraphStyle) {
        var composition: [NSAttributedString.Key: Any] = attributes
        composition[.paragraphStyle] = paragraphStyle

        self.attributes = composition
    }

    init(color: NSColor, fontSize: CGFloat, lineSpacing: CGFloat, blockType: BlocksInfo.Types) {
        let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = lineSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: fontSize),
            .paragraphStyle: paragraphStyle,
            .blockType: blockType,
            .inlineStyle: InlineStyles.none
        ]

        self.attributes = attributes
    }

    /// Returns the attributes for the given inline styles.
    func attributes(_ baseAttrs: [NSAttributedString.Key : Any], withStyles styles: InlineStyles) -> [NSAttributedString.Key : Any] {
        var attrs = self.attributes
        attrs[.inlineStyle] = styles

        if let link = baseAttrs[.link] as? URL {
            attrs[.link] = link
        }

        guard let baseFont = attrs[.font] as? NSFont else {
            return attrs
        }

        var fontTraits = NSFontTraitMask()

        if styles.contains(.bold) {
            fontTraits.insert(.boldFontMask)
        }

        if styles.contains(.italic) {
            fontTraits.insert(.italicFontMask)
        }

        if styles.contains(.underline) {
            attrs[.underlineStyle] = 1
        }

        if styles.contains(.highlight) {
            attrs[.backgroundColor] = NSColor.Primary.Highlight
        }

        if styles.contains(.code) {
            let baseCodeFont = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular)
            attrs[.font] = NSFontManager.shared.convert(baseCodeFont, toHaveTrait: fontTraits)
            attrs[.foregroundColor] = NSColor.Primary.Primary
            attrs[.backgroundColor] = NSColor.Grayscale.Offwhite
        } else if fontTraits != NSFontTraitMask() {
            attrs[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: fontTraits)
        }

        return attrs
    }
}
