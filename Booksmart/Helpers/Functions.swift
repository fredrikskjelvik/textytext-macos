import Foundation

/// Clamp a given value between a minimum and maximum value -- min(max(...))
func clamp<T: Comparable>(value: T, lower: T, upper: T) -> T {
	return min(max(value, lower), upper)
}

/// Absolute resource to bundle resource URL
func convertToBundleResourceURL(url: URL, defaultExtension: String = "") -> URL? {
    var path = url.lastPathComponent
    
    if url.pathExtension == "" {
        path += ".\(defaultExtension)"
        
        if defaultExtension == "" {
            return nil
        }
    }
    
    return Bundle.main.url(forResource: path, withExtension: nil)
}

/// Generate a random alphanumeric string of some length
func randomAlphaNumericString(length: Int) -> String {
    let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let allowedCharsCount = UInt32(allowedChars.count)
    var randomString = ""

    for _ in 0 ..< length {
        let randomNum = Int(arc4random_uniform(allowedCharsCount))
        let randomIndex = allowedChars.index(allowedChars.startIndex, offsetBy: randomNum)
        let newCharacter = allowedChars[randomIndex]
        randomString += String(newCharacter)
    }

    return randomString
}
