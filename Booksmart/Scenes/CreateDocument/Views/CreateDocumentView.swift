import SwiftUI
import RealmSwift
import PDFKit

struct CreateDocumentView: View {
    @EnvironmentObject var router: Router
    
    var body: some View {
        NavigationStack(path: $router.path) {
            VStack(alignment: .leading) {
                NavigationLink("Upload", value: UploadBookRoute())
            }
            .navigationDestination(for: UploadBookRoute.self) { route in
                UploadBookView()
            }
            .navigationDestination(for: EditOutlineRoute.self) { route in
                EditOutlineView()
            }
        }
        .padding(20)
    }
}
