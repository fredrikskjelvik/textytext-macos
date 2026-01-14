import SwiftUI
import RealmSwift
import Factory

struct ReaderScene: Scene {
    @Injected(Container.realm) private var realm
    @Injected(Container.userDefaults) private var userDefaults
    
    var body: some Scene {
        WindowGroup("Editor", id: "editor") {
            NotesContainer()
        }
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
        .commandsRemoved()
    }
}
