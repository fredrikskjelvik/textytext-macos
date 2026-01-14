//
//  SheetView.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 17/12/22.
//

import SwiftUI

enum SheetType {
    case newFolder
    case renameFolder
    case renameDocument

    func name() -> String {
        // Returns the name for the buttons.
        switch self {
        case .newFolder:
            return "Create"
        case .renameFolder, .renameDocument:
            return "Rename"
        }
    }
}

protocol SheetViewDelegate {
    func buttonTapped(text: String, type: SheetType)
}

struct SheetView: View {
    @FocusState private var focused: Bool

    var title: String = ""
    var placeHolder: String = ""
    var delegate: SheetViewDelegate?
    var type: SheetType
    @Binding var name: String
    @Binding var presentFolder: Bool

    var body: some View {
        VStack(spacing: 20) {
             VStack(spacing: 8) {
                 HStack {
                     Text(title)
                     Spacer()
                 }
                 TextField(placeHolder, text: $name)
                     .focused($focused)
             }
             
             HStack {
                 Button("Cancel", role: .cancel, action: {
                     presentFolder = false
                     focused = false
                 })

                 Button(type.name(), action: {
                     // Validate if the text is not empty.
                     if validate() {
                         delegate?.buttonTapped(text: name, type: type)
                         presentFolder = false
                         focused = false
                     }
                 })
                 .keyboardShortcut(.defaultAction)
             }
         }
         .padding()
         .frame(width: 260)
    }

    private func validate() -> Bool {
        // Trim spaces and then check if the text is empty.
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

struct DialogView_Previews: PreviewProvider {
    static var previews: some View {
        SheetView(type: .newFolder, name: .constant("Folder 1"), presentFolder: .constant(true))
    }
}
