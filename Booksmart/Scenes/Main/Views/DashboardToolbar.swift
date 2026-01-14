import SwiftUI
import RealmSwift

struct DashboardToolbar: ViewModifier {
    @EnvironmentObject var router: Router
    
    func body(content: Content) -> some View {
        content
            .navigationTitle("Reader")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: {}) { Image(systemName: "chevron.left") }
                    Button(action: {}) { Image(systemName: "chevron.right") }
                    
                    HStack {
                        Text("\(router.sidebarSelection?.label ?? "")")
                            .lineLimit(1)
                            .fixedSize()
                            .fontWeight(.bold)
                        
                        if router.sidebarSelection == FixedRoute.browseDocuments {
                            breadcrumb
                        }
                        
                        Spacer()
                    }
                }
                
                ToolbarItem() { Spacer() }
                
                ToolbarItem(placement: .automatic) {
                    Button(action: {}) { Image(systemName: "magnifyingglass") }
                }
            }
    }
    
    // MARK: Breadcrumb
    
    @State private var hoveringOverBreadcrumbId: ObjectId? = nil
    @State private var hoveringOverRootBreadcrumb = false
    
    var breadcrumb: some View {
        HStack {
            Divider()
            BreadcrumbView(text: BrowseFoldersAndDocumentsViewModel.rootFolder.name, hover: hoveringOverRootBreadcrumb, dragOver: router.dropFolder?.name ?? "" == BrowseFoldersAndDocumentsViewModel.rootFolder.name)
                .onHover { hover in
                    hoveringOverRootBreadcrumb = hover
                }
                .onTapGesture(count: 1) {
                    router.breadcrumbSelected = nil
                }
                .onDrop(of: [.item], delegate: DropFolderViewDelegate(folder: BrowseFoldersAndDocumentsViewModel.rootFolder, router: router))
            ForEach(router.breadcrumbs, id: \.self) { breadcrumb in
                Text(">")
                BreadcrumbView(text: breadcrumb.name , hover: breadcrumb.id == hoveringOverBreadcrumbId, dragOver: breadcrumb.id == router.dropFolder?.id)
                    .onHover { hover in
                        hoveringOverBreadcrumbId = hover ? breadcrumb.id : nil
                    }
                    .onTapGesture(count: 1) {
                        router.breadcrumbSelected = breadcrumb
                    }
                    .onDrop(of: [.item], delegate: DropFolderViewDelegate(folder: breadcrumb, router: router))
            }
            Spacer()
        }
    }
}

extension View {
    func dashboardToolbar() -> some View {
        modifier(DashboardToolbar())
    }
}
