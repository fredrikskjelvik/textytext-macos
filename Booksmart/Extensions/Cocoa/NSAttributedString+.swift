import Cocoa

/// An array of attributes and their corresponding ranges.
typealias AttributeRuns = [(attributes: [NSAttributedString.Key : Any], range: NSRange)]

extension NSAttributedString {
    /// Returns the attribute runs in the given range.
    func attributeRuns(in range: NSRange) -> AttributeRuns {
        var runs = AttributeRuns()

        enumerateAttributes(in: range, options: []) { attributes, range, _ in
            runs.append((attributes, range))
        }

        return runs
    }
}
