import SwiftUI
import RealmSwift

struct AllDocumentsView: View {
    static let maxNestedFoldersMessage = "This folder cannot be moved as it would exceed the maximum number of nested folders."
    private let columns = [
        GridItem(.adaptive(minimum: 150))
    ]

    @EnvironmentObject var model: BrowseFoldersAndDocumentsViewModel
    @State private var folderName = ""
    @State private var renameFolderName = ""
    @State private var presentNewFolder = false
    @State private var presentRenameFolder = false
    @State private var presentDeleteConfirmationAlert = false
    @State private var hoveringOverFolderId: ObjectId? = nil
    @State private var selectedFolderId: ObjectId? = nil

    fileprivate func folderContextMenu(_ folder: FolderDB) -> some View {
        Group {
            Button(action: {
                // Rename folder.
                model.folderToRename = folder
                renameFolderName = folder.name
                presentRenameFolder = true
            }, label: {
                Text("Rename")
            })
            Button(role: .destructive, action: {
                model.folderToDelete = folder
                // Ask for confirmation before deleting folder.
                presentDeleteConfirmationAlert = true
            }, label: {
                Text("Delete")
            })
        }
    }

    fileprivate var newFolderContextMenuButton: some View {
        return Button(action: {
            // Reset binding variable and create new folder.
            folderName = ""
            presentNewFolder = true
        }, label: {
            Text("New Folder")
        })
    }

    var body: some View {
        VStack(spacing: 30) {
            if model.isNotSearching && (model.previousParent.count > 0 || model.folders.count > 0) {
                VStack(spacing: 8) {
                    // Allow switching back to parent.
                    if model.previousParent.count > 0 {
                        BackView()
                            .onTapGesture {
                                // Go back in hierarchy of folders.
                                model.switchBack()
                            }
                    }
                    
                    if model.folders.count > 0 {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(model.folders.freeze(), id: \.self) { folder in
                                FolderView(folderName: folder.name, hover: folder.id == hoveringOverFolderId, selected: folder.id == selectedFolderId, dragOver: folder.id == model.dropFolder?.id)
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        folderContextMenu(folder)
                                    }
                                    .gesture(TapGesture(count: 2).onEnded({
                                        selectedFolderId = nil
                                        model.switchFolder(to: folder)
                                    }))
                                    .simultaneousGesture(TapGesture().onEnded({
                                        selectedFolderId = folder.id
                                    }))
                                    .onHover { hover in
                                        hoveringOverFolderId = hover ? folder.id : nil
                                    }
                                    .onDrag({
                                        return model.startDrag(for: folder)
                                    })
                                    .onDrop(of: [.item], delegate: DropFolderViewDelegate(model: model, folder: folder))
                            }
                        }
                    }
                }
            }
            
            DocumentListView()
            Spacer()
        }
        .contentShape(Rectangle())
        .contextMenu {
            if model.allowFolderCreation {
                newFolderContextMenuButton
            }
        }
        .sheet(isPresented: $presentNewFolder, content: {
            SheetView(title: "Create New Folder", placeHolder: "Folder name", delegate: model, type: .newFolder, name: $folderName, presentFolder: $presentNewFolder)
        })
        .sheet(isPresented: $presentRenameFolder, content: {
            SheetView(title: "Rename Folder", delegate: model, type: .renameFolder, name: $renameFolderName, presentFolder: $presentRenameFolder)
        })
        .confirmationDialog("Are you sure you want to delete this folder? This will delete all subfolders and files within this folder. This action is irreversible.", isPresented: $presentDeleteConfirmationAlert) {
            Button("Delete", role: .destructive) {
                // Delete folder.
                try? model.deleteFolder()
            }
            Button("Cancel", role: .cancel, action: {})
        }
        .alert(Self.maxNestedFoldersMessage, isPresented: $model.maxNestedFolderCountExceeded) {
            Button("OK", role: .cancel) {}
        }
        .onTapGesture {
            selectedFolderId = nil
        }
    }
}

struct BrowseFoldersAndDocumentsView_Previews: PreviewProvider {
    static var previews: some View {
        AllDocumentsView()
    }
}
