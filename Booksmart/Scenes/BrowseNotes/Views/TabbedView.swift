//
//  TabbedView.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 20/12/22.
//

import SwiftUI

enum Tab: CaseIterable {
    case allNotes
    case favourites
    case shared
    
    var name: String {
        switch self {
        case .allNotes:
            return "All Notes"
        case .favourites:
            return "Favourites"
        case .shared:
            return "Shared"
        }
    }

    var imageName: String {
        switch self {
        case .allNotes:
            return "doc.text"
        case .favourites:
            return "star"
        case .shared:
            return "square.and.arrow.up"
        }
    }
}

struct TabbedView: View {
    static private var selectedColor = Color.green
    static private var unSelectedColor = Color.secondary
    @Binding var selectedTab: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                VStack(spacing: 14) {
                    HStack {
                        Image(systemName: tab.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(tab == selectedTab ? Self.selectedColor : Self.unSelectedColor)
                        Text(tab.name)
                            .fontWeight(tab == selectedTab ? .bold : .regular)
                            .foregroundColor(tab == selectedTab ? .primary : Self.unSelectedColor)
                    }
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(tab == selectedTab ? Self.selectedColor : Self.unSelectedColor)
                }
                .frame(width: 125)
                .onTapGesture {
                    selectedTab = tab
                }
            }
            Spacer()
        }
    }
}

struct TabbedView_Previews: PreviewProvider {
    static var previews: some View {
        TabbedView(selectedTab: .constant(.allNotes))
    }
}
