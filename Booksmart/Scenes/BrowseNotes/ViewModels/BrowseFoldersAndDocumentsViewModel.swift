import Foundation
import RealmSwift
import Combine
import Factory

enum Drag {
    case none
    case folder
    case document
}

final class BrowseFoldersAndDocumentsViewModel: ObservableObject {
    @Injected(Container.realm) private var realm
    
    static let rootFolder = FolderDB(id: ObjectId.generate(), name: "Root")
    static private let maxNestedFolderCount = 4
    private var tokens = Set<NotificationToken?>()
    private var subscriptions = Set<AnyCancellable>()
    private var drag: Drag = .none
    var router: Router!
    var folderToRename: FolderDB? = nil
    var folderToDelete: FolderDB? = nil
    var documentToRename: DocumentDB? = nil
    var documentToDelete: DocumentDB? = nil
    var isNotSearching: Bool {
        searchText.trimmingCharacters(in: .whitespaces).count == 0
    }

    @Published var folders: Results<FolderDB>!
    @Published var documents: Results<DocumentDB>!
    @Published var favouriteDocuments: Results<DocumentDB>!
    @Published var parent: FolderDB? = nil
    @Published var allowFolderCreation = true
    @Published var selectedTab: Tab = .allNotes
    @Published var maxNestedFolderCountExceeded = false
    @Published var searchText: String = ""
    @Published var showNoRecordsFound: Bool = false
    @Published var showNoFavoritesFound: Bool = false
    // Keep a stack of folders for traversing back.
    @Published var previousParent: [FolderDB?] = []

    // Folder drag/drop related variables.
    var dragFolder: FolderDB?
    @Published var dropFolder: FolderDB?
    // Document drag/drop related variables.
    var dragDocument: DocumentDB?

    init() {
        // Retrieve the list of folders and documents.
        getFoldersAndDocuments(filteredBy: searchText)
        allowFolderCreation = true
        
        // Create a search subscription and apply search.
        $searchText.sink { [weak self] text in
            guard let strongSelf = self else { return }
            let searchText = text.trimmingCharacters(in: .whitespaces).lowercased()
            strongSelf.getFoldersAndDocuments(filteredBy: searchText)
        }
        .store(in: &subscriptions)
    }

    func setup(router: Router) {
        self.router = router
        // Remove previous selections.
        self.router.breadcrumbs.removeAll()
        self.router.breadcrumbSelected = nil
        // Create a subscription for breadcrumb selected.
        router.$breadcrumbSelected.sink { [weak self] folder in
            guard let strongSelf = self else { return }
            strongSelf.breadcrumbClicked(folder: folder)
        }
        .store(in: &subscriptions)
    }
    
    deinit {
        cancelSubscriptions()
        subscriptions.removeAll()
    }

    func breadcrumbClicked(folder: FolderDB?) {
        guard let folder = folder else {
            // Switch to root folder.
            router.breadcrumbs.removeAll()
            self.previousParent.removeAll()
            self.parent = nil
            // Refresh to root view.
            getFoldersAndDocuments(filteredBy: searchText)
            return
        }
        // If the user clicks on the last breadcrumb (current folder) do nothing.
        if router.breadcrumbs.last?.id == folder.id { return }
        // Remove all folders after selected folder from breadcrumbs.
        router.breadcrumbs.removeAll(where: { $0.ancestors.contains(where: { $0 == folder.id }) })
        self.previousParent.removeAll(where: { $0?.id == folder.id || $0?.ancestors.contains(where: { $0 == folder.id }) ?? false })
        // Reset parent.
        self.parent = folder
        getFoldersAndDocuments(filteredBy: searchText)
    }
    
    func switchFolder(to folder: FolderDB) {
        let parent = folder
        // Switch to the newly selected folder and display the sub folders and documents.
        self.previousParent.append(self.parent)
        self.parent = parent
        // Add breadcrumbs.
        if let parent = self.parent {
            router.breadcrumbs.append(parent)
        }
        getFoldersAndDocuments(filteredBy: searchText)
    }
    
    func switchBack() {
        // Go back to the previous folder and display the sub folders and documents.
        self.parent = self.previousParent.removeLast()
        // Remove breadcrumbs.
        if router.breadcrumbs.count > 0 {
            router.breadcrumbs.removeLast()
        }
        getFoldersAndDocuments(filteredBy: searchText)
    }

    private func canCreateFolder() -> Bool {
        guard let parentId = self.parent?.id else {
            return true
        }
        // Retrieve the list of folders from Realm based on parent folder selected.
        let parentFolder = realm.objects(FolderDB.self).where({ $0.id == parentId }).first
        // Do not allow nested folders beyond 5 levels.
        return parentFolder?.ancestors.count ?? 0 < Self.maxNestedFolderCount
    }

    func deleteFolder() throws {
        // Delete the current folder and all subfolders.
        guard let folderDB = folderToDelete, let folder = folderDB.thaw() else {
            return
        }
        var foldersToDelete = [FolderDB]()
        foldersToDelete.append(folder)
        
        // Retrieve all subfolders.
        let subFolders = Self.getSubFolders(for: folderDB)
        if subFolders.count > 0 {
            foldersToDelete.append(contentsOf: subFolders)
        }

        // Retrieve all documents within current folder and it's subfolders.
        let documentsToDelete = getDocuments(in: foldersToDelete)
        
        // Delete the selected folder, it's sub folders and files.
        try realm.write {
            realm.delete(foldersToDelete)
            realm.delete(documentsToDelete)
        }
    }

    func deleteDocument() throws {
        // Delete the current document.
        guard let documentDB = documentToDelete, let documentToDelete = documentDB.thaw() else {
            return
        }
        // Delete the selected document in realm.
        try realm.write {
            realm.delete(documentToDelete)
        }
    }

    func toggleFavorite(for document: DocumentDB) throws {
        guard let document = document.thaw() else {
            return
        }
        // Mark the selected document as favourite.
        try realm.write {
            document.favourite = !document.favourite
            document.updatedAt = Date()
        }
    }

    // MARK: Private functions.

    private func validateFolder(name: String) -> Bool {
        return isNotEmpty(text: name)
    }

    private func validateDocument(name: String) -> Bool {
        return isNotEmpty(text: name)
    }

    private func isNotEmpty(text: String) -> Bool {
        return !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func createFolder(name: String) throws {
        // Folder name cannot be empty.
        guard validateFolder(name: name) else {
            return
        }
        // Create the folder within the parent selected. By default, the parent is nil.
        let folderDb = FolderDB(name: name, parent: self.parent?.id)
        let ancestors = List<ObjectId>()
        // Find parent folder and setup ancestors. This helps deleting sub folders when a folder is deleted.
        // Reference: https://www.mongodb.com/docs/manual/tutorial/model-tree-structures-with-ancestors-array/
        
        if let parent = self.parent {
            if let parentFolderDB = realm.objects(FolderDB.self).where({ $0.id == parent.id }).first, parentFolderDB.ancestors.count > 0 {
                ancestors.append(objectsIn: parentFolderDB.ancestors)
            }
            ancestors.append(parent.id)
        }
        folderDb.ancestors = ancestors
        try realm.write {
            realm.add(folderDb)
        }
    }
    
    private func renameFolder(newName: String) throws {
        // Folder name cannot be empty.
        guard validateFolder(name: newName) else {
            return
        }
        // Rename the selected folder.
        guard let folder = folderToRename?.thaw() else {
            return
        }
        try realm.write {
            folder.name = newName
            folder.updatedAt = Date()
        }
    }

    private func renameDocument(newName: String) throws {
        // Document name cannot be empty.
        guard validateDocument(name: newName) else {
            return
        }
        // Rename the selected document.
        guard let document = documentToRename?.thaw() else {
            return
        }
        try realm.write {
            document.name = newName
            document.updatedAt = Date()
        }
    }

    private func getDocuments(in folders: [FolderDB]) -> List<DocumentDB> {
        let allDocuments = List<DocumentDB>()
        // Retrieve all files within the folders list.
        folders.forEach({ folder in
            let documents = realm.objects(DocumentDB.self).where({ document in
                document.folder.id == folder.id
            })
            allDocuments.append(objectsIn: documents)
        })
        return allDocuments
    }

    static func getSubFolders(for folderDB: FolderDB) -> Results<FolderDB> {
        // Retrieve the list of subfolders for the given folder.
        let realm = Container.realm.callAsFunction()
        let subFolders = realm.objects(FolderDB.self).where({ $0.ancestors.contains(folderDB.id) })
        return subFolders
    }

    private func getFoldersAndDocuments(filteredBy searchText: String) {
        // Retrieve the list of folders from Realm based on parent folder selected.
        folders = realm.objects(FolderDB.self).where({ $0.parent == self.parent?.id })

        // Retrieve the list of documents from Realm based on parent folder selected.
        documents = realm.objects(DocumentDB.self).where({
            if let folderId = self.parent {
                return $0.folder.id == folderId.id
            }
            return $0.folder == nil
        })
        // Retrieve the list of documents from Realm that are marked as favourites.
        favouriteDocuments = realm.objects(DocumentDB.self).where({ $0.favourite == true })

        if !searchText.isEmpty {
            // Filter documents.
            documents = documents.filter("name CONTAINS[c] %@", searchText)
            // Filter favourite documents.
            favouriteDocuments = favouriteDocuments.filter("name CONTAINS[c] %@", searchText)
            
            showNoRecordsFound = documents.count == 0
            showNoFavoritesFound = favouriteDocuments.count == 0
        }
        else {
            showNoRecordsFound = false
            showNoFavoritesFound = false
        }

        // Create subscriptions for documents and folders.
        createSubscriptions()
        // Check if folders can be created.
        allowFolderCreation = canCreateFolder()
    }
    
    private func createSubscriptions() {
        // Cancel any active subscriptions.
        cancelSubscriptions()
        // Add subscription to folders.
        tokens.insert(
            folders?.observe({ (changes) in
                switch changes {
                case .error(_):
                    break
                case .initial(_):
                    break
                case .update(_, deletions: _, insertions: _, modifications: _):
                    self.objectWillChange.send()
                }
            })
        )
        // Add subscription to documents.
        tokens.insert(
            documents?.observe({ (changes) in
                switch changes {
                case .error(_):
                    break
                case .initial(_):
                    break
                case .update(_, deletions: _, insertions: _, modifications: _):
                    self.objectWillChange.send()
                }
            })
        )
        tokens.insert(
            favouriteDocuments?.observe({ (changes) in
                switch changes {
                case .error(_):
                    break
                case .initial(_):
                    break
                case .update(_, deletions: _, insertions: _, modifications: _):
                    self.objectWillChange.send()
                }
            })
        )
    }

    private func cancelSubscriptions() {
        // Cancel subscription by releasing the tokens.
        tokens.removeAll()
    }
}

extension BrowseFoldersAndDocumentsViewModel: SheetViewDelegate {
    func buttonTapped(text: String, type: SheetType) {
        switch type {
        case .newFolder:
            try? createFolder(name: text)
        case .renameFolder:
            try? renameFolder(newName: text)
        case .renameDocument:
            try? renameDocument(newName: text)
        }
    }
}

extension BrowseFoldersAndDocumentsViewModel {
    // MARK: Drag/Drop related functions for Folder.

    func startDrag(for folder: FolderDB) -> NSItemProvider {
        dragDocument = nil
        dragFolder = folder
        drag = .folder
        // Add folder drag/drop info to router.
        router.dragDocument = nil
        router.dragFolder = folder
        router.drag = .folder
        return NSItemProvider(object: NSString())
    }

    func dropEntered(folder: FolderDB) {
        // Used for highlighting the drop folder.
        dropFolder = dragFolder?.id != folder.id ? folder : nil
    }
    
    func dropExited() {
        dropFolder = nil
    }

    func performDrop() -> Bool {
        defer {
            // Reset variables.
            dragFolder = nil
            dropFolder = nil
            dragDocument = nil
            drag = .none
        }
        switch drag {
        case .none:
            return false
        case .folder:
            let result = Self.performDropFolder(dragFolder: dragFolder, dropFolder: dropFolder)
            maxNestedFolderCountExceeded = result.maxNestedFolderCountExceeded
            return result.result
        case .document:
            return Self.performDropDocument(dragDocument: dragDocument, dropFolder: dropFolder)
        }
    }

    static func performDropFolder(dragFolder: FolderDB?, dropFolder: FolderDB?) -> (result: Bool, maxNestedFolderCountExceeded: Bool) {
        guard let dragFolder = dragFolder, let parent = dropFolder else {
            return (false, false)
        }

        // Retrieve all subfolders.
        let subFolders = Self.getSubFolders(for: dragFolder)

        // Validate ancestors only when dragFolder.ancestors.count >= dropFolder.ancestors.count.
        // Check the number of sub folders for the folder being dragged.
        if dragFolder.ancestors.count == parent.ancestors.count && ((subFolders.max(by: { $0.ancestors.count < $1.ancestors.count })?.ancestors.count ?? 0 >= Self.maxNestedFolderCount) || (dragFolder.ancestors.count == Self.maxNestedFolderCount && subFolders.count == 0)) {
            return (false, true)
        }

        // Update drag folder's parent and ancestors.
        let realm = Container.realm.callAsFunction()
        try? realm.write {
            // Build ancestors - dropFolder.ancestors + dropFolder.id
            var newAncestors = Array(parent.ancestors)
            if parent.id != Self.rootFolder.id {
                newAncestors.append(parent.id)
            }
            
            if subFolders.count > 0 {
                subFolders.forEach({
                    guard let folder = $0.thaw() else {
                        return
                    }
                    // Remove dragFolder ancestors from subfolders.
                    let count = dragFolder.ancestors.count
                    folder.ancestors.remove(atOffsets: IndexSet(0..<count))
                    if newAncestors.count > 0 {
                        // Update ancestors for all child folders within drag folder.
                        folder.ancestors.insert(contentsOf: newAncestors, at: 0)
                    }
                    folder.updatedAt = Date()
                })
            }

            guard let dragFolder = dragFolder.thaw() else {
                return
            }
            if parent.id == Self.rootFolder.id {
                dragFolder.parent = nil
                dragFolder.ancestors.removeAll()
            }
            else {
                dragFolder.parent = parent.id
                dragFolder.ancestors.removeAll()
                dragFolder.ancestors.append(objectsIn: newAncestors)
            }
            dragFolder.updatedAt = Date()
        }
        return (true, false)
    }

    // MARK: Drag/Drop related functions for Document.

    func startDrag(for document: DocumentDB) -> NSItemProvider {
        guard selectedTab == .allNotes else {
            // Drag is not allowed in favorites tab as it doesn't contain any folders.
            return NSItemProvider()
        }
        dragFolder = nil
        dragDocument = document
        drag = .document
        router.dragFolder = nil
        router.dragDocument = document
        router.drag = .document
        return NSItemProvider(object: NSString())
    }

    static func performDropDocument(dragDocument: DocumentDB?, dropFolder: FolderDB?) -> Bool {
        guard let dragDocument = dragDocument, let dropFolder = dropFolder else {
            return false
        }

        // Update drag documents's folder.
        let realm = Container.realm.callAsFunction()
        try? realm.write {
            guard let dragDocument = dragDocument.thaw() else {
                return
            }
            if dropFolder.id == Self.rootFolder.id {
                dragDocument.folder = nil
            }
            else {
                dragDocument.folder = dropFolder.thaw()
            }
            dragDocument.updatedAt = Date()
        }
        return true
    }
}
