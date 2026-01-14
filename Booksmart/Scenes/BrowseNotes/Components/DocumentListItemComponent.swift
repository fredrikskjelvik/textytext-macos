import SwiftUI
import RealmSwift

struct DocumentListItemComponent: View {
    let document: DocumentDB
    @Binding var selectedDocument: ObjectId?
    var onDoubleClick: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 10.0) {
            Image(systemName: IconKeys.folder)
                .font(.system(size: 24))
            
            Text(document.name)
                .font(.title2)
            
            Spacer()
        }
        .padding(.horizontal, 20.0)
        .padding(.vertical, 15.0)
        .frame(width: 250)
        .cornerRadius(15)
        .border(selectedDocument == document.id ? .blue : .black)
        .gesture(TapGesture(count: 2).onEnded {
            onDoubleClick()
        })
        .simultaneousGesture(TapGesture().onEnded {
            selectedDocument = document.id
        })
        .contextMenu {
            Button(action: onDelete, label: {
                Label("Delete", systemImage: IconKeys.trash)
            })
        }
    }
}

struct DocumentListItemComponent_Previews: PreviewProvider {
    static var previews: some View {
        let document = DocumentDB(name: "Science")
        
        DocumentListItemComponent(document: document, selectedDocument: .constant(nil), onDoubleClick: {}, onDelete: {})
    }
}

