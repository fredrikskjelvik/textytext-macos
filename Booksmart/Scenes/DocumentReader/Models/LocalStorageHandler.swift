import Cocoa

enum LocalStorageHandlerErrors: Error {
    // Getting
    case CouldNotGetLocalStorageDirectory
    case FileDoesNotExist(String)
    case FileRetrievalFailure(String)
    case InvalidFileType
    
    // Setting
    case TiffConversionFailed
    case FileTypeNotSupported
    case FileAlreadyExists
}

/// Store files in the user's file system (in a designated directory).
/// And retrieve them.
class LocalStorageHandler {
    /// Create the local storage directory if it doesn't exist, if that doesn't work, throw error
    init() throws {
        if FileManager.default.directoryExists(atPath: localStorageDirectory.relativePath) {
            return
        }
        
        try FileManager.default.createDirectory(at: localStorageDirectory, withIntermediateDirectories: false)
    }
    
    /// The URL of the directory where files are stored locally on the users computer!
    /// - E.g. for photos that are uploaded in the textview.
    /// - Also note that during development this directory is inside of a sandbox, so e.g. documents directory is not the actual documents directory.
    var localStorageDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("booksmart-local")
//        return URL(string: "/Users/fredrik/Documents/booksmart-local")
//        let documentsUrl = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as NSURL
    }
    
    // MARK: Images
    
    /// Get image from local storage directory and return as Data.
    /// Supports JPEG and PNG.
    ///
    /// - Throws: LocalStorageHandlerErrors.FileDoesNotExist - File not found
    /// - Throws: LocalStorageHandlerErrors.FileRetrievalFailure(fileName) - File was found, but its data could not be accessed
    func getImage(withFileName fileName: String) throws -> Data {
        var imagePath: String
        let jpegPath = localStorageDirectory.appendingPathComponent(fileName + ".jpeg").relativePath
        let pngPath = localStorageDirectory.appendingPathComponent(fileName + ".png").relativePath
        
        if FileManager.default.fileExists(atPath: jpegPath) {
            imagePath = jpegPath
        } else if FileManager.default.fileExists(atPath: pngPath) {
            imagePath = pngPath
        } else {
            throw LocalStorageHandlerErrors.FileDoesNotExist(fileName)
        }
        
        guard let data = FileManager.default.contents(atPath: imagePath) else {
            throw LocalStorageHandlerErrors.FileRetrievalFailure(fileName)
        }
        
        return data
    }
    
    /// Store an image in the user's local storage directory
    ///
    /// Only JPEG and PNG files are supported. If a file already exists with the same name, it does nothing.
    /// - Parameters:
    ///   - image: the image to store
    ///   - fileName: the name to give the file. A random string without the file file ending, the correct file ending ".png/.jpeg" is determined when saving and loading.
    ///
    /// - Throws: LocalStorageHandlerErrors.TiffConversionFailed - if NSImage cannot be converted to data at all
    /// - Throws: LocalStorageHandlerErrors.FileTypeNotSupported - if image could not be written to file as neither JPEG nor PNG.
    func setImage(image: NSImage, withName fileName: String) throws {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else {
            throw LocalStorageHandlerErrors.TiffConversionFailed
        }
        
        do
        {
            if let jpegData = bitmap.representation(using: .jpeg, properties: [:]) {
                let url = localStorageDirectory.appendingPathComponent(fileName + ".jpeg")
                if FileManager.default.fileExists(atPath: url.relativePath) {
                    return
                }
                
                try jpegData.write(to: url)
            }
            else if let pngData = bitmap.representation(using: .png, properties: [:])
            {
                let url = localStorageDirectory.appendingPathComponent(fileName + ".png")
                if FileManager.default.fileExists(atPath: url.relativePath) {
                    return
                }
                
                try pngData.write(to: url)
            }
            else
            {
                throw LocalStorageHandlerErrors.FileTypeNotSupported
            }
        }
        catch
        {
            throw error
        }
    }
    
    // MARK: Books
    
    func getBook(fileName: String) throws -> Data {
        let url = localStorageDirectory.appendingPathComponent(fileName)
        let path = url.relativePath
        
        guard url.pathExtension == "pdf" || url.pathExtension == "epub" else {
            throw LocalStorageHandlerErrors.InvalidFileType
        }
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw LocalStorageHandlerErrors.FileDoesNotExist(fileName)
        }
        
        guard let data = FileManager.default.contents(atPath: path) else {
            throw LocalStorageHandlerErrors.FileRetrievalFailure(fileName)
        }
        
        return data
    }
    
    func setBook(pdf: Data, fileName: String) throws {
        let url = localStorageDirectory.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: url.relativePath) == false else {
            throw LocalStorageHandlerErrors.FileAlreadyExists
        }
        
        guard url.pathExtension == "pdf" || url.pathExtension == "epub" else {
            throw LocalStorageHandlerErrors.InvalidFileType
        }
        
        try pdf.write(to: url, options: .atomic)
    }
    
    func deleteFile(fileName: String) throws {
        let url = localStorageDirectory.appendingPathComponent(fileName)
        
        try FileManager.default.removeItem(at: url)
    }
}
