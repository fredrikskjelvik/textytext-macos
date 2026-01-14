import SwiftUI
import Factory

@main
struct BooksmartApp: SwiftUI.App {
    @Injected(Container.realm) private var realm
    @Injected(Container.userDefaults) private var userDefaults
    
    var body: some Scene {
        WindowGroup("Dashboard", id: "dashboard") {
            ContentView()
                .environmentObject(Router())
                .environmentObject(CreateDocumentVM())
                .preferredColorScheme(userDefaults.darkMode ? .dark : .light)
                .environment(\.realm, realm)
        }
        .commands {
            SidebarCommands()
        }
        .windowStyle(.hiddenTitleBar)
        
        ReaderScene()
        
        Settings {
            SettingsView()
        }
    }
}
