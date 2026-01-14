import Cocoa

/// A struct/enum that contains basic information about a block type
protocol BlockInfo {
	static var name: String { get }
	static var description: String { get }
	static var markdownKey: String? { get }
    static var icon: NSImage? { get }
}

/// This struct contains configuration for all the block types.
struct BlocksInfo {
	/// Not meant to be initialized
	private init() {}
	
	/// Dictionary of every block type and its BlockInfo enum
	static let map: [Types: BlockInfo.Type] = [
        .text: text.self,
		.header1: header1.self,
        .header2: header2.self,
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
		case codesnippet
		case flashcard
		case emphasized
		case image
        
        /// Some blocks span multiple lines (currently only codesnippet), and this distinction is relevant in many cases
        func isSingleLine() -> Bool {
            switch self
            {
            case .codesnippet:
                return false

            default:
                return true
            }
        }
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
        static let color = NSColor.Monochrome.RegularBlack
		
		/// the characters that turn something into this block type via markdown. In this case a text block can't be
		/// created via markdown, but e.g. for a header it would be "#"
		static let markdownKey: String? = nil
        static let icon = NSImage(systemSymbolName: "textformat", accessibilityDescription: nil)
	}
	
	enum header1: BlockInfo {
		static let name: String = "Header 1"
		static let description: String = "Big section heading"
		
		static let textSize = FontSizes.xxxlarge
		static let paragraphSpacing: Double = 15.0
		static let lineSpacing: Double = 6.0
		static let color = NSColor.Monochrome.RegularBlack
		
		static let markdownKey: String? = "#"
        static let icon = NSImage(systemSymbolName: "textformat", accessibilityDescription: nil)
	}
	
	enum header2: BlockInfo {
		static let name: String = "Header 2"
		static let description: String = "Medium section heading"
		
		static let textSize = FontSizes.xxlarge
		static let paragraphSpacing: Double = 12.0
		static let lineSpacing: Double = 5.0
		static let color = NSColor.Monochrome.RegularBlack
		
		static let markdownKey: String? = "##"
        static let icon = NSImage(systemSymbolName: "textformat", accessibilityDescription: nil)
	}
	
	enum list: BlockInfo {
		static let name: String = "List"
		static let description: String = "Simple bullet list"
		
		static let textSize = FontSizes.medium
		static let paragraphSpacing: Double = 7.0
		static let lineSpacing: Double = 3.0
		static let color = NSColor.Monochrome.RegularBlack
		
		static let markdownKey: String? = "-"
        static let icon = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: nil)
	}
	
	enum orderedlist: BlockInfo {
		static let name: String = "Ordered List"
		static let description: String = "Simple numbered list"
		
		static let textSize = FontSizes.medium
		static let paragraphSpacing: Double = 7.0
		static let lineSpacing: Double = 3.0
		static let color = NSColor.Monochrome.RegularBlack
		
		static let markdownKey: String? = "1."
        static let icon = NSImage(systemSymbolName: "list.number", accessibilityDescription: nil)
	}
	
	enum codesnippet: BlockInfo {
		static let name: String = "Code Snippet"
		static let description: String = "Code block with syntax highlighting"
		
		static let textSize = FontSizes.small
		static let paragraphSpacing: Double = 11.0
		static let lineSpacing: Double = 2.0
		static let color = NSColor.Monochrome.RegularBlack
		
		static let markdownKey: String? = "```"
        static let icon = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
	}

    enum image: BlockInfo {
        static let name: String = "Image"
        static let description: String = "Embedded image"

        static let markdownKey: String? = nil
        static let icon = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
    }
}
