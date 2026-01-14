//
//  TitleView.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 17/12/22.
//

import SwiftUI

struct TitleView: View {
    var title: String = ""
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title)
            Spacer()
        }
    }
}

struct TitleView_Previews: PreviewProvider {
    static var previews: some View {
        TitleView()
    }
}
