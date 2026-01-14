import Cocoa

class UserDefaultsManager {
    // MARK: Setup
    
    static var standard = UserDefaultsManager()
    private var defaults = UserDefaults.standard
    private init() {}
    
    // MARK: Keys
    
    private struct Constants {
        static let darkMode = "darkMode"
    }
    
    // MARK: Getting/Setting
    
    var darkMode: Bool {
        get {
            if let darkMode = defaults.object(forKey: Constants.darkMode) {
                return darkMode as! Bool
            }
            
            return false
        }
        set {
            defaults.set(newValue, forKey: Constants.darkMode)
        }
    }
    
    // MARK: Other
    
    func clearAll() {
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
    }
}
