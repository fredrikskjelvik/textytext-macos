//
//  FolderView.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 16/12/22.
//

import SwiftUI

struct FolderView: View {
    var folderName: String
    var hover: Bool = false
    var selected: Bool = false
    var dragOver: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.green)
            Text(folderName)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 5.0)
                .strokeBorder(selected ? Color.blue.opacity(0.8) : Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: selected ? 2 : 1))
        )
        .background(dragOver ? .blue : hover ? .gray.opacity(0.5) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 5.0))
    }
}

struct FolderView_Previews: PreviewProvider {
    static var previews: some View {
        FolderView(folderName: "Folder Name")
    }
}
