import Cocoa

struct StyleBuilder {
    /// Inline styles mask. Represents a combination of InlineStyles.
    struct InlineStyles: OptionSet {
        let rawValue: Int

        static let none       = InlineStyles([])
        static let bold       = InlineStyles(rawValue: 1 << 1)
        static let italic     = InlineStyles(rawValue: 1 << 2)
        static let underline  = InlineStyles(rawValue: 1 << 3)
        static let code       = InlineStyles(rawValue: 1 << 4)
        static let highlight  = InlineStyles(rawValue: 1 << 5)
        static let pageLink   = InlineStyles(rawValue: 1 << 6)

        init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Initialize InlineStyles from keydown event, using the keycode and modifier flags.
        ///
        /// Is used when user e.g. holds down command and presses b to make some text bold.
        init?(from event: NSEvent) {
            guard event.modifierFlags.contains(.command) else {
                return nil
            }
            
            let keyCode = event.keyCode
            let holdingShift = event.modifierFlags.contains(.shift)
            let combined = (keyCode, holdingShift)
            
            switch combined
            {
                case (Keycode.b, _):
                    self = .bold
                case (Keycode.i, _):
                    self = .italic
                case (Keycode.u, _):
                    self = .underline
                case (Keycode.c, true):
                    self = .code
                case (Keycode.b, true):
                    self = .highlight
                default:
                    return nil
            }
        }

        /// Add additional inline style to existing style
        ///
        /// E.g. add italic to already bold text
        func inserting(_ inlineStyle: InlineStyles) -> InlineStyles {
            var copy = self
            copy.insert(inlineStyle)
            return copy
        }

        /// Remove one inline style from existing style
        func removing(_ inlineStyle: InlineStyles) -> InlineStyles {
            var copy = self
            copy.remove(inlineStyle)
            return copy
        }
    }

    /// The attributes in the format that TextKit actually uses to apply style
    var attributes: [NSAttributedString.Key: Any]

    /// Initialize style from raw dictionary
    init(attributes: [NSAttributedString.Key: Any]) {
        self.attributes = attributes
    }

    /// Initialize style from raw dictionary AND paragraph style
    init(attributes: [NSAttributedString.Key: Any], paragraphStyle: NSMutableParagraphStyle) {
        var composition: [NSAttributedString.Key: Any] = attributes
            composition[.paragraphStyle] = paragraphStyle

        self.attributes = composition
    }

    /// Define styling with some helper parameters
    ///
    /// Blocks use this initializer to define their default/initial styling
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
    
    /// Given some text's existing base attributes and a style, return the updated attributes with the style
    /// - Parameters:
    ///   - baseAttrs: existing attributes
    ///   - styles: inline style
    /// - Returns: attributes with inline style applied
    func attributes(_ baseAttrs: [NSAttributedString.Key : Any], withStyles styles: InlineStyles) -> [NSAttributedString.Key : Any] {
        var attrs = self.attributes
        attrs[.inlineStyle] = styles

        if let link = baseAttrs[.link] as? URL {
            attrs[.link] = link
        }
        
        if let pageLinkTo = baseAttrs[.pageLinkTo] as? Int {
            attrs[.pageLinkTo] = pageLinkTo
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
            attrs[.backgroundColor] = NSColor.Primary.Light
        }
        
        if styles.contains(.pageLink)
        {
            attrs[.backgroundColor] = NSColor.blue
            attrs[.foregroundColor] = NSColor.white
        }

        if styles.contains(.code)
        {
            let baseCodeFont = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular)
            attrs[.font] = NSFontManager.shared.convert(baseCodeFont, toHaveTrait: fontTraits)
            attrs[.foregroundColor] = NSColor.Primary.Regular
            attrs[.backgroundColor] = NSColor.Monochrome.LightGray
        }
        else if fontTraits != NSFontTraitMask()
        {
            attrs[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: fontTraits)
        }

        return attrs
    }
    
    /// Struct for encoding a range of text with a particular style.
    struct Coded: Codable {
        private enum Keys: CodingKey {
            case range
            case inlineStyle
            case pageLinkTo
            case link
        }
        
        let range: NSRange
        var attributes: [NSAttributedString.Key: Any]
        
        init(range: NSRange, attributes: [NSAttributedString.Key: Any]) {
            self.range = range
            self.attributes = attributes
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            
            self.range = try container.decode(NSRange.self, forKey: Keys.range)
            self.attributes = [:]
            
            if let link = try? container.decode(URL.self, forKey: Keys.link) {
                self.attributes[.link] = link
            }
            
            if let pageLinkTo = try? container.decode(Int.self, forKey: Keys.pageLinkTo) {
                self.attributes[.pageLinkTo] = pageLinkTo
            }
            
            if let inlineStyle = try? container.decode(Int.self, forKey: Keys.inlineStyle) {
                self.attributes[.inlineStyle] = InlineStyles(rawValue: inlineStyle)
            }
            
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Keys.self)
            
            try container.encode(range, forKey: Keys.range)
            try container.encode(attributes[.link] as? URL, forKey: Keys.link)
            try container.encode(attributes[.pageLinkTo] as? Int, forKey: Keys.pageLinkTo)
            try container.encode((attributes[.inlineStyle] as? InlineStyles)?.rawValue, forKey: Keys.inlineStyle)
        }
    }
}
