import Foundation

extension CharacterSet {
    /// This is the character for linebreak, meaning it doesn't break into a new paragraph, it just appears on the next line.
    static let lineBreak = CharacterSet(charactersIn: String.linebreak)
    
    /// This is all the characters for "new line", meaning all characters that should create a new paragraph
    static let newLine = CharacterSet.newlines.subtracting(CharacterSet.lineBreak)
}
