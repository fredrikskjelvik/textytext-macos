import Foundation

extension Data {
    
    // TODO: Check if it works, but probably delete it cause I won't use it
    func getImageFileExtension() -> String? {
        var values = [UInt8](repeating:0, count:1)
        self.copyBytes(to: &values, count: 1)

        switch (values[0])
        {
        case 0xFF:
            return ".jpeg"
        case 0x89:
            return ".png"
        case 0x47:
            return ".gif"
        case 0x49, 0x4D :
            return ".tiff"
        default:
            return nil
        }
    }
}
