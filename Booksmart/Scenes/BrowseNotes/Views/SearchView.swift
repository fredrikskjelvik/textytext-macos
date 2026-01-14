//
//  SearchView.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 20/12/22.
//

import SwiftUI

struct SearchView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(searchText.count > 0 ? .primary : .secondary)
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(EdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6))
        .cornerRadius(10.0)
        .overlay(
            RoundedRectangle(cornerRadius: 5.0)
                .strokeBorder(.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1))
                .background(.clear)
        )
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(searchText: .constant("search"))
    }
}
