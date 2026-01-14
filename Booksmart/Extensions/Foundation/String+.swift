extension String {
	
	/// Count instances of given substring in string
	/// - Parameter stringToFind: substring to count instances of
	/// - Returns: Int - number of instances
	func countInstances(of stringToFind: String) -> Int {
		assert(!stringToFind.isEmpty)
		var count = 0
		var searchRange: Range<String.Index>?
		
		while let foundRange = range(of: stringToFind, options: [], range: searchRange) {
			count += 1
			searchRange = Range(uncheckedBounds: (lower: foundRange.upperBound, upper: endIndex))
		}
		
		return count
	}
	
	/// Unicode character for linebreak (\r)
	static let linebreak = String("\u{2028}")

}
