//
//  BackView.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 16/12/22.
//

import SwiftUI

struct BackView: View {
    var body: some View {
        HStack {
            Image(systemName: "chevron.left")
            Text("Back")
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

struct BackView_Previews: PreviewProvider {
    static var previews: some View {
        BackView()
    }
}
