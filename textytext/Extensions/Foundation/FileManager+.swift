import Foundation

extension FileManager {
    func directoryExists(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = true
        let fileExists = fileExists(atPath: path, isDirectory: &isDirectory)

        return fileExists && isDirectory.boolValue
    }
}
