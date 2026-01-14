import SwiftUI

struct EditOutlineView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var vm: CreateDocumentVM
    
    var body: some View {
        VStack(spacing: 20) {
            if let book = vm.bookUploadHandler
            {
                Text("Edit Table of Contents")
                    .font(.largeTitle)

                Text("Uploaded PDF might have an incomplete or poorly formatted table of contents, as well as unnecessary chapters. Feel free to update them.")

                List(Array(book.outline)) { item in
                    EditOutlineListItem(
                        item: item,
                        onDelete: {
                            book.outline.deleteItem(item)
                            vm.objectWillChange.send()
                        },
                        onEdit: { newValue in
                            item.label = newValue
                        },
                        addSiblingBelow: {
                            book.outline.addSiblingBelow(item)
                            vm.objectWillChange.send()
                        },
                        addChild: {
                            book.outline.addChild(item)
                            vm.objectWillChange.send()
                        },
                        shiftLeft: {
                            book.outline.shiftLeft(item)
                            vm.objectWillChange.send()
                        },
                        shiftRight: {
                            book.outline.shiftRight(item)
                            vm.objectWillChange.send()
                        }
                    )
                }

                Button("Submit", action: {
                    if vm.createDocument() == true {
                        print("Success!")
                        router.path.removeLast(router.path.count)
                    }
                })
            }
            else
            {
                Text("Error!!!")
            }
        }
        .navigationTitle("Edit outline")
    }
}


struct EditOutlineListItem: View {
    @State var item: OutlineItem
    
    var onDelete: () -> Void
    var onEdit: (String) -> Void
    var addSiblingBelow: () -> Void
    var addChild: () -> Void
    var shiftLeft: () -> Void
    var shiftRight: () -> Void

    @State private var editLabel = false

    var body: some View {
        HStack {
            if editLabel == false
            {
                Text(item.label)
                Button("Edit") {
                    editLabel = true
                }
                Button("Delete", action: onDelete)
                Button("Add sibling below", action: addSiblingBelow)
                Button("Add child", action: addChild)
                Button("<", action: shiftLeft)
                Button(">", action: shiftRight)
            }
            else
            {
                TextField("", text: $item.label).onSubmit {
                    editLabel = false
                    onEdit(item.label)
                }
            }

            Spacer()

            Text(String(item.page))
        }
        .tag(item.id)
        .font(.system(size: 20))
        .foregroundColor(Color.black)
        .padding(EdgeInsets(top: 10, leading: Double(5 + 30 * item.chapter.depth()), bottom: 10, trailing: 0))
    }

}
