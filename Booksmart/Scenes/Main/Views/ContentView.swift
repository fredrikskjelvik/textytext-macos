import SwiftUI
import RealmSwift

struct ContentView: View {
    @EnvironmentObject var router: Router

    var body: some View {
        NavigationSplitView {
            List(selection: $router.sidebarSelection) {
                ForEach(router.sidebarSections) { section in
                    Section(section.name) {
                        ForEach(section.routes) { route in
                            NavigationLink(value: route, label: {
                                Label(route.label, systemImage: route.icon)
                            })
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onAppear {
                // By default, select the first item in the list.
                DispatchQueue.main.async {
                    router.sidebarSelection = router.sidebarSections.first?.routes.first
                }
            }
        } detail: {
            switch router.sidebarSelection {
            case FixedRoute.createDocument:
                CreateDocumentView()
                    .navigationTitle("Create document")
            case FixedRoute.browseDocuments:
                // BrowseDocumentsView()
                BrowseDocumentsTabView()
                    .navigationTitle("Browse documents")
                    .alert(AllDocumentsView.maxNestedFoldersMessage, isPresented: $router.maxNestedFolderCountExceeded) {
                        Button("OK", role: .cancel) {}
                    }
            case FixedRoute.library:
                Text("Library")
                    .navigationTitle("Library")
            case FixedRoute.bookStore:
                BookStoreView()
                    .environmentObject(BookStoreVM())
                    .navigationTitle("Book Store")
            default:
                Text("Error???")
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .dashboardToolbar()
    }
}
