import Cocoa

extension NSRange {
    // Check if range fully contains the range passed as parameter within it
    public func contains(range: NSRange) -> Bool {
        return location <= range.location && (location + length) >= (range.location + range.length)
    }
}
