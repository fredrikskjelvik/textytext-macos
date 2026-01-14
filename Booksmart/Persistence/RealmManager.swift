import Foundation
import RealmSwift
import PDFKit

/// Singleton class with a property with an instance of Realm, so that the same instance of Realm can be accessed anywhere.
/// Also does/can contain otther things, like adding dummy data.
class RealmManager {
    let realm: Realm
    
    init() {
        do {
            let config = Realm.Configuration(deleteRealmIfMigrationNeeded: true)
            self.realm = try Realm(configuration: config)
//            addData()
        }
        catch let error as NSError {
            fatalError(error.localizedDescription)
        }
    }
    
    func addData() {
        try! realm.write {
            realm.deleteAll()
//
//            for book in ["Bioinformatics", "AlgorithmicTrading", "MML"]
//            {
//                let document = DocumentDB(name: book)
//
//                if let fileUrl = Bundle.main.url(forResource: book, withExtension: "pdf"),
//                   let pdfDoc = PDFDocument(url: fileUrl)
//                {
//                    document.book = BookDB(name: book, format: .pdf, file: fileUrl, pages: pdfDoc.pageCount)
//
//                    document.outlineItems.append(
//                        OutlineItemDB(label: "Root", page: 0, chapter: Chapter([0]))
//                    )
//                    document.outlineItems.append(
//                        OutlineItemDB(label: "Chapter 1", page: 5, chapter: Chapter([0, 0]))
//                    )
//                    document.outlineItems.append(
//                        OutlineItemDB(label: "Chapter 1.1", page: 10, chapter: Chapter([0, 0, 0]))
//                    )
//                    document.outlineItems.append(
//                        OutlineItemDB(label: "Chapter 1.2", page: 20, chapter: Chapter([0, 0, 1]))
//                    )
//                    document.outlineItems.append(
//                        OutlineItemDB(label: "Chapter 2", page: 30, chapter: Chapter([0, 1]))
//                    )
//                    document.outlineItems.append(
//                        OutlineItemDB(label: "Chapter 2.1", page: 40, chapter: Chapter([0, 1, 0]))
//                    )
//                    document.outlineItems.append(
//                        OutlineItemDB(label: "Chapter 2.2", page: 50, chapter: Chapter([0, 1, 1]))
//                    )
//                    document.outlineItems.append(
//                        OutlineItemDB(label: "Chapter 3", page: 60, chapter: Chapter([0, 2]))
//                    )
//                    document.outlineItems.append(
//                        OutlineItemDB(label: "Chapter 3.1", page: 80, chapter: Chapter([0, 2, 0]))
//                    )
//                    document.outlineItems.append(
//                        OutlineItemDB(label: "Chapter 3.2", page: 90, chapter: Chapter([0, 2, 1]))
//                    )
//                    document.outlineItems.append(
//                        OutlineItemDB(label: "Chapter 3.3", page: 100, chapter: Chapter([0, 2, 2]))
//                    )
//                    document.outlineItems.append(
//                        OutlineItemDB(label: "Chapter 3.4", page: 110, chapter: Chapter([0, 2, 3]))
//                    )
//                }
//                else
//                {
//                    continue
//                }
//
//                document.note = NoteDB()
//
//                for item in document.outlineItems
//                {
//                    document.note!.noteChapters.append(NoteChapterDB(outlineItem: item, contents: nil))
//                }
//
//                folder.documents.append(document)
//            }
        }
    }
}
