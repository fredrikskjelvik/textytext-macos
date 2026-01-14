//
//  SharedView.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 20/12/22.
//

import SwiftUI

struct SharedView: View {
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            Text("There are no shared documents.")
            Spacer()
        }
    }
}

struct SharedView_Previews: PreviewProvider {
    static var previews: some View {
        SharedView()
    }
}
