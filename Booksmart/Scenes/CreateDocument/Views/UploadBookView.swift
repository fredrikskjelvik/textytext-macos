import SwiftUI

struct UploadBookView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var vm: CreateDocumentVM
    
    @State private var showFileExplorerPanel = false
    
    var body: some View {
        VStack {
            Text("Upload book PDF")
                .font(.largeTitle)

            Button("Upload...") {
                showFileExplorerPanel = true
            }
            .fileImporter(isPresented: $showFileExplorerPanel, allowedContentTypes: [.pdf]) { result in
                switch result
                {
                case .success(let url):
                    vm.onSelectFile(url: url)
                case .failure(let error):
                    print(error)
                }
            }

            if let uploadHandler = vm.bookUploadHandler {
                Text("Uploaded file: \(uploadHandler.fileName)")
            }
            
            Button("Next") {
                router.path.removeLast()
                router.path.append(EditOutlineRoute())
            }
        }
        .navigationTitle("Upload book")
    }
}
