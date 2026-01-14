import Foundation
import PDFKit
import Factory

enum BookUploadErrors: Error {
    case invalidFileType
    case couldNotRetrieveTableOfContents
    case couldNotAccessLocalStorage
    case unreadableFile
}

struct BookUploadHandler {
    @Injected(Container.realm) private var realm
    
    var document: PDFDocument
    var outline: OutlineContainer
    let url: URL
    
    var fileName: String {
        url.lastPathComponent
    }
    
    init(url: URL) throws {
        guard let document = PDFDocument(url: url) else {
            throw BookUploadErrors.invalidFileType
        }
        
        self.document = document
        
        guard
            let root = document.outlineRoot,
            let outlineContainer = OutlineContainerFactory.createFromPdfDocument(root)
        else { throw BookUploadErrors.couldNotRetrieveTableOfContents }
            
        self.outline = outlineContainer
        self.url = url
    }
    
    func createDocument() throws {
        let savedName = try saveBookInLocalStorage()
        
        let noteDb = NoteDB()
        let bookDb = BookDB(name: fileName, format: .pdf, fileName: savedName, pages: document.pageCount)

        let documentDb = DocumentDB(name: outline.root.label)
            documentDb.note = noteDb
            documentDb.book = bookDb

        for item in Array(outline)
        {
            item.realmObject.label = item.label
            item.realmObject.page = item.page
            item.realmObject.chapter = item.chapter

            documentDb.outlineItems.append(item.realmObject)
        }

        try? realm.write {
            realm.add(documentDb)
        }
    }
    
    private func saveBookInLocalStorage() throws -> String {
        let name = randomAlphaNumericString(length: 20) + "." + url.pathExtension
        
        guard url.pathExtension == "pdf" || url.pathExtension == "epub" else{
            throw BookUploadErrors.invalidFileType
        }
        
        guard let storage = try? LocalStorageHandler() else {
            throw BookUploadErrors.couldNotAccessLocalStorage
        }
        
        guard let bookData = try? Data(NSData(contentsOfFile: url.relativePath)) else {
            throw BookUploadErrors.unreadableFile
        }

        try storage.setBook(pdf: bookData, fileName: name)
        
        return name
    }
}

class CreateDocumentVM: ObservableObject {
    @Published var bookUploadHandler: BookUploadHandler? = nil
    
    func onSelectFile(url: URL) {
        self.bookUploadHandler = try? BookUploadHandler(url: url)
    }
    
    func createDocument() -> Bool {
        guard let bookUploadHandler = bookUploadHandler else {
            return false
        }
        
        guard let _ = try? bookUploadHandler.createDocument() else {
            return false
        }
        
        return true
    }
}
