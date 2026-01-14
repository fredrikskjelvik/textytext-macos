import SwiftUI

struct NavigationSidebar: View {
    private enum PickerRoute {
        case search
        case thumbnail
        case outline
        case highlights
    }

    @State private var pickerSelection: PickerRoute = .search

    @EnvironmentObject var readerState: ReaderState

    var body: some View {
        TabView(selection: $pickerSelection) {
            SearchReaderView(outlineContainer: readerState.outlineContainer)
                .tabItem {
                    Text("Search")
                }
                .tag(PickerRoute.search)
            ThumbnailViewContainer(readerState: readerState)
                .tabItem {
                    Text("Thumbnails")
                }
                .tag(PickerRoute.thumbnail)

            BookOutlineView()
                .tabItem {
                    Text("Outline")
                }
                .tag(PickerRoute.outline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
    }
}

struct NavigationSidebar_Previews: PreviewProvider {
    static var previews: some View {
        NavigationSidebar()
    }
}



//struct NavigationSidebar: View {
//    @State private var pickerSelection = 0
//
//    @EnvironmentObject var readerState: ReaderState
//
//    var body: some View {
//        VStack(alignment: .center) {
//            picker
//
//            switch pickerSelection
//            {
//            case 0:
//                SearchReaderView(outlineContainer: readerState.outlineContainer)
//            case 1:
//                ThumbnailViewContainer(readerState: readerState)
//            case 2:
//                BookOutlineView()
//            case 3:
//                Text("Highlights")
//            default:
//                Text("Herroo")
//            }
//
//            Spacer()
//        }
//        .frame(minWidth: 200, idealWidth: 260, maxWidth: 400, alignment: .center)
//        .padding(.vertical, 12)
//        .padding(.horizontal, 6)
//    }
//
//    var picker: some View {
//        Picker("", selection: $pickerSelection) {
//            IconWithHelpText(icon: IconKeys.search, text: "Search all")
//                .tag(0)
//
//            IconWithHelpText(icon: "square.stack", text: "Thumbnails")
//                .tag(1)
//
//            IconWithHelpText(icon: "book", text: "Book Outline")
//                .tag(2)
//
//            IconWithHelpText(icon: "highlighter", text: "Highlights")
//                .tag(3)
//
//            IconWithHelpText(icon: "square.on.square", text: "Flashcards")
//                .tag(4)
//        }
//        .pickerStyle(.segmented)
//        .frame(width: 200)
//    }
//}
