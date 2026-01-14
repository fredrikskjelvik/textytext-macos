import SwiftUI
import RealmSwift
import Factory

struct ReaderScene: Scene {
    @Injected(Container.realm) private var realm
    @Injected(Container.userDefaults) private var userDefaults
    
    var body: some Scene {
        WindowGroup("Reader", id: "reader", for: ObjectId.self) { $id in
            if let id {
                ReaderLoader(documentId: id)
                    .preferredColorScheme(userDefaults.darkMode ? .dark : .light)
                    .environment(\.realm, realm)
            } else {
                Text("Error")
            }
        }
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
        .commandsRemoved()
    }
}
