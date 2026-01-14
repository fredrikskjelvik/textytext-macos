//
//  FavouritesView.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 20/12/22.
//

import SwiftUI

struct FavouritesView: View {
    @EnvironmentObject var model: BrowseFoldersAndDocumentsViewModel

    var body: some View {
        DocumentListView()
            .environmentObject(model)
    }
}

struct FavouritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavouritesView()
    }
}
