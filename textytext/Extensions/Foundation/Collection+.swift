extension Collection {
	
    /// Safely access a specific index of a collection. Output optional.
    /// - Parameter index: index to access
    /// - Returns: Optional element
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }

}
