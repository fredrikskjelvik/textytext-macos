import SwiftUI

struct BrowseFlashcardsChapterHeader: View {
    let name: String
    let size: Font
    var body: some View {
        HStack(alignment: .center, spacing: 6){
            Text(name)
            Spacer()
        }
        .font(size)
        .onTapGesture {}
    }
}

struct ChapterHeader_Previews: PreviewProvider {
    static var previews: some View {
        BrowseFlashcardsChapterHeader(name: "Chapter 1", size: .largeTitle)
    }
}

