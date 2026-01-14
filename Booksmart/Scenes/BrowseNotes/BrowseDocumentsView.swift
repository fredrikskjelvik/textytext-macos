import SwiftUI
import RealmSwift

struct BrowseDocumentsView: View {
    @Environment(\.realm) var realm
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var router: Router
    
    @ObservedResults(DocumentDB.self) var documents
    @State private var selectedDocument: ObjectId? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(alignment: .center, spacing: 5) {
                    ForEach(documents) { document in
                        DocumentListItemComponent(
                            document: document,
                            selectedDocument: $selectedDocument,
                            onDoubleClick: {
                                openWindow(id: "reader", value: document.id)
                            },
                            onDelete: {
                                delete(document: document)
                            })
                    }
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
        .padding(20)
    }
    
    func delete(document: DocumentDB) {
        let document = document.thaw()!
        
        try? realm.write {
            realm.delete(document)
        }
    }
}







//struct BrowseNotesView: View {
//	@EnvironmentObject var dashboardState: DashboardState
//    @EnvironmentObject var navigator: Navigator
//
//    /// Selected, highlighted item (i.e. a document or a folder)
//	  @State private var selectedItem: ObjectId? = nil
//
//    var selectedDocument: DocumentDB? {
//        dashboardState.documents.first(where: { $0.id == selectedItem })
//    }
//
//	var body: some View {
//        HStack {
//            VStack(alignment: .leading) {
//                ForEach(dashboardState.folder.subfolders) { folder in
//                    HStack(spacing: 10) {
//                        Image(systemName: "folder.fill")
//                            .font(.system(size: 30))
//                        Text(folder.name)
//                            .font(.title2)
//                    }
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(20.0)
//                    .cornerRadius(10)
//                    .border(selectedItem == folder.id ? .blue : .gray)
//                    .gesture(TapGesture(count: 2).onEnded {
//                        dashboardState.folder = folder
//                    })
//                    .simultaneousGesture(TapGesture().onEnded {
//                        selectedItem = folder.id
//                    })
//                }
//
//                Spacer().frame(height: 30)
//
//                ForEach(dashboardState.folder.documents) { document in
//                    HStack(spacing: 10) {
//                        Image(systemName: "book.fill")
//                            .font(.system(size: 30))
//                        Text(document.name)
//                            .font(.title2)
//                    }
//                    .tag(document.id)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(20.0)
//                    .cornerRadius(10)
//                    .border(selectedItem == document.id ? .blue : .gray)
//                    .gesture(TapGesture(count: 2).onEnded {
//                        navigator.navigate("/reader/\(document.id)")
//                    })
//                    .simultaneousGesture(TapGesture().onEnded {
//                        selectedItem = document.id
//                    })
//                }
//
//                Spacer()
//
//                HStack {
//                    addFolderButton
//
//                    Button("Add document") {
//                        print("Add document")
//                    }
//
//                    Spacer()
//                }
//            }
//            .padding(25)
//
//            Spacer()
//
//            if let selectedDocument = selectedDocument
//            {
//                VStack {
//                    if let pdfDoc = selectedDocument.book!.getPDFDocument()
//                    {
//                        Image(nsImage: pdfDoc.getFirstPageThumbnail(size: NSSize(width: 200, height: 300)))
//                    }
//                    Text(selectedDocument.name).font(.largeTitle)
//
//                    Divider()
//
//                    Text("Notes")
//                }
//                .frame(minWidth: 400, idealWidth: 400, maxWidth: 400, maxHeight: .infinity)
//                .background(Color.gray)
//                .edgesIgnoringSafeArea(.all)
//            }
//        }
//        .dashboardToolbar()
//    }
//
////    func tempGetImage() {
////        let storage = LocalStorageHandler()
////        do {
////            let url = URL(string: "/Users/fredrik/Downloads/nature.jpeg")!
////            let image = NSImage(byReferencingFile: url.relativePath)!
////            try storage.setImage(image: image, withName: "meme123")
////        }
////        catch {
////            print(error)
////        }
////    }
//
//    // MARK: "Add Folder" button
//    @State private var folderCreationPopupIsPresented = false
//    @State private var folderCreationTextField = ""
//
//    var addFolderButton: some View {
//        Button("Add folder") {
//            folderCreationPopupIsPresented = true
//        }
//        .popover(isPresented: $folderCreationPopupIsPresented) {
//            HStack {
//                TextField("Folder name", text: $folderCreationTextField)
//
//                Button("Add") {
//                    dashboardState.addFolder(name: folderCreationTextField)
//                    folderCreationPopupIsPresented = false
//                }
//            }
//            .padding()
//        }
//    }
//}
