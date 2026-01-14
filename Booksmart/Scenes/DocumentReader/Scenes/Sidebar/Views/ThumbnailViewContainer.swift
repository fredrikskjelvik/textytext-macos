import PDFKit
import SwiftUI

struct ThumbnailViewContainer: View {
    @StateObject var vm: ThumbnailViewerState
    
    @EnvironmentObject var readerState: ReaderState
    var bookState: BookState {
        readerState.bookState
    }
    
    init(readerState: ReaderState) {
        self._vm = StateObject(wrappedValue: ThumbnailViewerState(parent: readerState.bookState))
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            picker
            
            ScrollViewReader { proxy in
                ScrollView {
                    Text("").hidden().tag(-1)
                    LazyVStack(alignment: .center, spacing: 15) {
                        ForEach(vm.displayedPages, id: \.id) { page in
                            Button(action: {
                                bookState.currentPage = page.pageNumber
                            }, label: {
                                VStack(spacing: 6) {
                                    Image(nsImage: page.getThumbnail(size: NSSize(width: 300, height: 450)))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: 400, alignment: .center)
                                    Text(String(page.pageNumber)).font(.body)
                                }
                            })
                            .buttonStyle(.plain)
                            .tag(page.pageNumber)
                        }
                    }
                    .onChange(of: vm.pickerSelection) { selection in
                        if selection == .allPages
                        {
                            proxy.scrollTo(bookState.currentPage, anchor: UnitPoint.center)
                        }
                        else
                        {
                            proxy.scrollTo(-1)
                        }
                    }
                }
            }
        }
    }
    
    var picker: some View {
        Picker("", selection: $vm.pickerSelection) {
            Text("All Pages").tag(PickerSelection.allPages)
            Text("Bookmarks").tag(PickerSelection.bookmarks)
        }
        .pickerStyle(.segmented)
    }
}
