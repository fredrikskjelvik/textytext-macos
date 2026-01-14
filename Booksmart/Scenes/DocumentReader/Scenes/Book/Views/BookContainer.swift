import SwiftUI

struct BookContainer: View {
    @State var canUndo: Bool = false
    @State var canRedo: Bool = false
    
    var body: some View {
        VStack {
            BookReaderToolbarView(canUndo: canUndo, canRedo: canRedo)
            PDFViewContainer(canUndo: $canUndo, canRedo: $canRedo)
        }
    }
}

//struct BookContainer_Previews: PreviewProvider {
//    static var previews: some View {
//        BookContainer()
//    }
//}
