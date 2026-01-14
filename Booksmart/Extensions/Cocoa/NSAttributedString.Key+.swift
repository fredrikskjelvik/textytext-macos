import Cocoa

extension NSAttributedString.Key {
	// Block type (e.g. header, text, list)
	static let blockType: NSAttributedString.Key = .init("blockType")
	
	// Inline style (e.g. bold, italic, underline)
	static let inlineStyle: NSAttributedString.Key = .init("inlineStyle")
	
	// Some parts are unselectable, for example the marker and space in a list (actually the only example)
	static let unselectable: NSAttributedString.Key = .init("unselectable")
}
