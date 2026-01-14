import SwiftUI
import RealmSwift
import Factory

struct ReaderLoader: View {
    @Injected(Container.realm) private var realm
    
    let documentId: ObjectId
    
    func getReaderState() -> ReaderState? {
        guard let document = realm.objects(DocumentDB.self).first(where: { $0.id == documentId }) else {
            return nil
        }
        
        return ReaderState(document: document)
    }
    
    var body: some View {
        if let readerState = getReaderState()
        {
            Reader()
                .environmentObject(readerState)
        }
        else
        {
            Text("Failed!")
        }
    }
}
