//
//  CenteredTextView.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 21/12/22.
//

import SwiftUI

struct CenteredTextView: View {
    var text: String

    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            Text(text)
            Spacer()
        }
    }
}

struct CenteredTextView_Previews: PreviewProvider {
    static var previews: some View {
        CenteredTextView(text: "Vertically and horizontally centered text.")
    }
}
