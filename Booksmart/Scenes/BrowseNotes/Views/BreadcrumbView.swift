//
//  BreadcrumbView.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 03/01/23.
//

import SwiftUI

struct BreadcrumbView: View {
    var text: String = ""
    var hover: Bool = false
    var dragOver: Bool = false

    var body: some View {
        Text(text)
            .padding([.vertical], 3)
            .padding([.horizontal], 6)
            .background(dragOver ? .blue : hover ? .gray.opacity(0.5) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 5.0))
    }
}

struct BreadcrumbView_Previews: PreviewProvider {
    static var previews: some View {
        BreadcrumbView()
    }
}
