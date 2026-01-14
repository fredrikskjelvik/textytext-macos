import Foundation
import SwiftUI
import RealmSwift

final class Router: ObservableObject {
    @Published var path = NavigationPath()
    @Published var sidebarSelection: FixedRoute? = nil

    // Breadcrumb related variables.
    @Published var breadcrumbs: [FolderDB] = []
    @Published var breadcrumbSelected: FolderDB? = nil
    var dragFolder: FolderDB?
    var dragDocument: DocumentDB?
    var drag: Drag = .none
    @Published var dropFolder: FolderDB?
    @Published var maxNestedFolderCountExceeded = false

    var sidebarSections: [SidebarSection] = [
        SidebarSection(name: "Documents", routes: [FixedRoute.createDocument, FixedRoute.browseDocuments]),
        SidebarSection(name: "Books", routes: [FixedRoute.library, FixedRoute.bookStore]),
    ]
    
    func goToSidebarSelection(_ route: FixedRoute) {
        path.removeLast(path.count)
        sidebarSelection = route
    }

    func dropEntered(folder: FolderDB) {
        // Used for highlighting the drop folder.
        // Do not allow drop in same parent folder.
        if drag == .folder {
            dropFolder = dragFolder?.parent != folder.id ? (dragFolder?.parent == nil && folder.id == BrowseFoldersAndDocumentsViewModel.rootFolder.id) ? nil : folder : nil
        }
        else if drag == .document {
            dropFolder = dragDocument?.folder?.id != folder.id ? (dragDocument?.folder == nil && folder.id == BrowseFoldersAndDocumentsViewModel.rootFolder.id) ? nil : folder : nil
        }
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
            let result = BrowseFoldersAndDocumentsViewModel.performDropFolder(dragFolder: dragFolder, dropFolder: dropFolder)
            maxNestedFolderCountExceeded = result.maxNestedFolderCountExceeded
            return result.result
        case .document:
            return BrowseFoldersAndDocumentsViewModel.performDropDocument(dragDocument: dragDocument, dropFolder: dropFolder)
        }

    }
}

struct SidebarSection: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let routes: [FixedRoute]
}

struct FixedRoute: Hashable, Identifiable {
    let id: String
    let label: String
    let icon: String
    
    static let createDocument = FixedRoute(id: "createDocument", label: "Create Document", icon: "plus.app")
    static let browseDocuments = FixedRoute(id: "browseDocuments", label: "Browse Documents", icon: "rectangle.3.offgrid")
    static let library = FixedRoute(id: "library", label: "Library", icon: "books.vertical")
    static let bookStore = FixedRoute(id: "bookStore", label: "Book Store", icon: "bag")
}

protocol RouteWithInfo: Identifiable, Hashable {
    var id: String { get }
    var name: String { get }
}

struct UploadBookRoute: RouteWithInfo {
    let id = UUID().uuidString
    let name = "Upload book"
}

struct EditOutlineRoute: RouteWithInfo {
    let id = UUID().uuidString
    let name = "Edit outline"
}




//enum Route: Hashable, Identifiable {
//    case createDocument
//        case uploadBook
//        case editOutline
//    case browseDocuments
//    case document
//    case bookStore
//    case library
//
//    var id: String {
//        switch self
//        {
//        case .createDocument:
//            return "createDocument"
//        case .uploadBook:
//            return "uploadBook"
//        case .editOutline:
//            return "editOutline"
//        case .browseDocuments:
//            return "browseDocuments"
//        case .document:
//            return "document"
//        case .bookStore:
//            return "bookStore"
//        case .library:
//            return "library"
//        }
//    }
//
//    var label: String {
//        switch self
//        {
//        case .createDocument:
//            return "Create Document"
//        case .uploadBook:
//            return "Upload Book"
//        case .editOutline:
//            return "Edit Outline"
//        case .browseDocuments:
//            return "Browse Notes"
//        case .document:
//            return "Document"
//        case .bookStore:
//            return "Book Store"
//        case .library:
//            return "Library"
//        }
//    }
//
//    var icon: String {
//        switch self
//        {
//        case .createDocument:
//            return "plus.app"
//        case .uploadBook:
//            return "heart"
//        case .editOutline:
//            return "heart"
//        case .browseDocuments:
//            return "rectangle.3.offgrid"
//        case .document:
//            return "Document"
//        case .bookStore:
//            return "bag"
//        case .library:
//            return "books.vertical"
//        }
//    }
//}
