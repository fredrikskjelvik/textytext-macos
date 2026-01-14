import SwiftUI
import RealmSwift

fileprivate let documentColumns = [
    GridItem(.flexible())
]

struct DocumentListView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var model: BrowseFoldersAndDocumentsViewModel

    @State private var renameDocumentName = ""
    @State private var presentRenameDocument = false
    @State private var presentDocumentDeleteConfirmationAlert = false

    fileprivate func documentContextMenu(_ document: DocumentDB) -> some View {
        Group {
            Button(action: {
                // Rename document.
                try? model.toggleFavorite(for: document)
            }, label: {
                Label("Favourite", systemImage: "checkmark")
                    .if(document.favourite, transform: { view in
                        view
                            .labelStyle(.titleAndIcon)
                    })
            })
            Button(action: {
                // Rename document.
                model.documentToRename = document
                renameDocumentName = document.name
                presentRenameDocument = true
            }, label: {
                Text("Rename")
            })

            Divider()

            Button(role: .destructive, action: {
                model.documentToDelete = document
                // Ask for confirmation before deleting document.
                presentDocumentDeleteConfirmationAlert = true
            }, label: {
                Text("Delete")
            })
        }
    }

    var body: some View {
        LazyVGrid(columns: documentColumns, spacing: 10) {
            ForEach(model.selectedTab == .favourites ? model.favouriteDocuments.freeze() : model.documents.freeze(), id: \.self) { document in
                DocumentRowView(document: document)
                    .contentShape(Rectangle())
                    .contextMenu {
                        documentContextMenu(document)
                    }
                    .onTapGesture(count: 2) {
                        openWindow(id: "reader", value: document.id)
                    }
                    .onDrag {
                        // Drag is not allowed in favorites tab as it doesn't contain any folders.
                        return model.startDrag(for: document)
                    }
                Divider()
            }
        }
        .sheet(isPresented: $presentRenameDocument, content: {
            SheetView(title: "Rename Document", delegate: model, type: .renameDocument, name: $renameDocumentName, presentFolder: $presentRenameDocument)
        })
        .confirmationDialog("Are you sure you want to delete the document?", isPresented: $presentDocumentDeleteConfirmationAlert) {
            Button("Delete", role: .destructive) {
                // Delete document.
                try? model.deleteDocument()
            }
            Button("Cancel", role: .cancel, action: {})
        }
    }
}

struct DocumentListView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentListView()
    }
}
