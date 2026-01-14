import Cocoa

protocol BlockInfo {
	static var name: String { get }
	static var description: String { get }
	static var markdownKey: String? { get }
    static var icon: NSImage? { get }
}

fileprivate let iconPlaceholder = { () -> NSImage? in
    guard let icon = NSImage(systemSymbolName: "textformat", accessibilityDescription: nil) else {
        return nil
    }

    icon.isTemplate = false
    return icon
}()

/// This struct contains configuration for all the block types. Everything is static and it's not meant to be initialized.
/// All of the block types contain information like their name and description (for the block selection menu), font
/// size etc. (only for text based blocks), markdown key
struct BlocksInfo {
	/// Disallows initialization
	private init() {}
	
	/// Dictionary of every block type config
	/// TODO: There's a problem that when doing markdown, it first identifies a header1 because of "#" and so converting to
	/// header 2 ("##") doesn't work properly. For now I just put .header2 before .header1, which should work. A more rigorous solve
	/// is to create a method that returns a dictionary in this form but in reverse order of length of markdown key.
	/// Problem: It doesn't iterate dictionary in this order. So temp solution doesn't work. Will fix later. Possible (quick) solution:
	/// https://gist.github.com/SR3u/c063a9dfc9383ddc783547e61060c5c8
	static let map: [Types: BlockInfo.Type] = [
		.text: text.self,
		.header2: header2.self,
		.header1: header1.self,
		.list: list.self,
		.orderedlist: orderedlist.self,
		.codesnippet: codesnippet.self,
        .image: image.self
	]
	
	/// Helper method to return the configuration for a specific block type
	static func get(_ type: Types) -> BlockInfo.Type? {
		return BlocksInfo.map[type]
	}
	
	/// Default font sizes
	enum FontSizes {
		static let xxsmall: CGFloat = 10
		static let xsmall: CGFloat = 12
		static let small: CGFloat = 14
		static let medium: CGFloat = 18
		static let large: CGFloat = 20
		static let xlarge: CGFloat = 24
		static let xxlarge: CGFloat = 28
		static let xxxlarge: CGFloat = 34
	}
	
	/// Block types
    enum Types: Int, RawRepresentable, Codable {
		case text
		case header1
		case header2
		case list
		case orderedlist
		case chapter
		case subchapter
		case codesnippet
		case flashcard
		case emphasized
		case image
	}
	
	/// Configuration for the text block. I will add documentation for every property, and all the enums
	/// below are basically the same but different
	enum text: BlockInfo {
		/// name and description shown in the block selection menu that pops up when you type "/"
		static let name: String = "Text"
		static let description: String = "Just plain text"
		
		/// text formatting for this block
		static let textSize = FontSizes.medium
		static let paragraphSpacing: Double = 5.0
		static let lineSpacing: Double = 3.0
		static let color = NSColor.Grayscale.Body
		
		/// the characters that turn something into this block type via markdown. In this case a text block can't be
		/// created via markdown, but e.g. for a header it would be "#"
		static let markdownKey: String? = nil
        static let icon = iconPlaceholder
	}
	
	enum header1: BlockInfo {
		static let name: String = "Header 1"
		static let description: String = "Big section heading"
		
		static let textSize = FontSizes.xxxlarge
		static let paragraphSpacing: Double = 15.0
		static let lineSpacing: Double = 6.0
		static let color = NSColor.Grayscale.Title
		
		static let markdownKey: String? = "#"
        static let icon = iconPlaceholder
	}
	
	enum header2: BlockInfo {
		static let name: String = "Header 2"
		static let description: String = "Medium section heading"
		
		static let textSize = FontSizes.xxlarge
		static let paragraphSpacing: Double = 12.0
		static let lineSpacing: Double = 5.0
		static let color = NSColor.Grayscale.Title
		
		static let markdownKey: String? = "##"
        static let icon = iconPlaceholder
	}
	
	enum list: BlockInfo {
		static let name: String = "List"
		static let description: String = "Simple bullet list"
		
		static let textSize = FontSizes.medium
		static let paragraphSpacing: Double = 7.0
		static let lineSpacing: Double = 3.0
		static let color = NSColor.Grayscale.Body
		
		static let markdownKey: String? = "-"
        static let icon = iconPlaceholder
	}
	
	enum orderedlist: BlockInfo {
		static let name: String = "Ordered List"
		static let description: String = "Simple numbered list"
		
		static let textSize = FontSizes.medium
		static let paragraphSpacing: Double = 7.0
		static let lineSpacing: Double = 3.0
		static let color = NSColor.Grayscale.Body
		
		static let markdownKey: String? = "1."
        static let icon = iconPlaceholder
	}
	
	enum codesnippet: BlockInfo {
		static let name: String = "Code Snippet"
		static let description: String = "Code block with syntax highlighting"
		
		static let textSize = FontSizes.small
		static let paragraphSpacing: Double = 11.0
		static let lineSpacing: Double = 2.0
		static let color = NSColor.Grayscale.Body
		
		static let markdownKey: String? = "```"
        static let icon = iconPlaceholder
	}

    enum image: BlockInfo {
        static let name: String = "Image"
        static let description: String = "Embedded image"

        static let markdownKey: String? = nil
        static let icon = iconPlaceholder
    }
}

extension BlocksInfo.Types {
    func isSingleLine() -> Bool {
        switch self {
        case .codesnippet:
            return false

        default:
            return true
        }
    }
}
