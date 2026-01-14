//
//  DocumentRowView.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 18/12/22.
//

import SwiftUI

struct DocumentRowView: View {
    static let thumbNailSize = NSSize(width: 50, height: 50)
    static let numberOfPages: Int = 28
    var document: DocumentDB

    var body: some View {
        HStack {
            if let pdfDoc = document.book?.getPDFDocument(), let image = pdfDoc.getFirstPageThumbnail(size: Self.thumbNailSize) {
                HStack {
                    Spacer()
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50, alignment: .center)
                        .cornerRadius(5.0)
                    Spacer()
                }
                .frame(width: 45, height: 55)
                .background(.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 5.0))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.title3)
                HStack {
                    // - a book icon + “pdf” or “epub” (what file type it is)
                    HStack {
                        Image(systemName: "book")
                            .foregroundColor(.green.opacity(0.6))
                        Text("\(document.book?.format.rawValue ?? "-")")
                    }
                    Divider()
                        .frame(height: 16)

                    // a document icon + number of pages of notes (just hard code a random number for now)
                    HStack {
                        Image(systemName: "doc")
                            .foregroundColor(.green.opacity(0.6))
                        Text("\(Self.numberOfPages)")
                    }
                    Divider()
                        .frame(height: 16)
                    
                    // a flashcard icon + number of flashcards in document
                    HStack {
                        Image(systemName: "square.on.square")
                            .foregroundColor(.green.opacity(0.6))
                        Text("\(document.flashcards.count) Flashcards")
                    }
                    Divider()
                        .frame(height: 16)
                    
                    // - a clock/date icon + date last accessed document
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.green.opacity(0.6))
                        Text("\(document.updatedAt.formatted())")
                    }

                    Spacer()
                }
                .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

struct FileView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentRowView(document: DocumentDB(name: "PDF Book"))
    }
}
