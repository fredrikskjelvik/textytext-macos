import SwiftUI

struct BrowseDocumentsTabView: View {
    @EnvironmentObject var router: Router
    @StateObject var model = BrowseFoldersAndDocumentsViewModel()

    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 30) {
                TitleView(title: "Browse Documents")
                
                HStack {
                    TabbedView(selectedTab: $model.selectedTab)
                    
                    Spacer()
                    
                    SearchView(searchText: $model.searchText)
                        .frame(width: 200)
                }
            }
            .padding([.leading, .trailing])

            switch model.selectedTab {
            case .allNotes:
                if model.showNoRecordsFound {
                    CenteredTextView(text: "Did not find any documents matching search text.")
                }
                else {
                    ScrollView(.vertical) {
                        VStack {
                            AllDocumentsView()
                        }
                        .padding([.leading, .trailing])
                    }
                    .frame(maxHeight: .infinity)
                }
            case .favourites:
                if model.showNoFavoritesFound {
                    CenteredTextView(text: "Did not find any favorite documents matching search text.")
                }
                else {
                    if model.favouriteDocuments.count > 0 {
                        ScrollView(.vertical) {
                            VStack {
                                FavouritesView()
                            }
                            .padding([.leading, .trailing])
                        }
                        .frame(maxHeight: .infinity)
                    }
                    else {
                        CenteredTextView(text: "There are no favorited documents.")
                    }
                }
            case .shared:
                SharedView()
            }
        }
        .environmentObject(model)
        .padding([.top])
        .onAppear() {
            model.setup(router: self.router)
        }
    }
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        BrowseDocumentsTabView()
    }
}
