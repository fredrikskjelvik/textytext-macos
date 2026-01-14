import SwiftUI

struct SettingsView: View {
    enum Tabs: Hashable {
        case general, advanced
    }
    
    @State var selection: Tabs = .general
    
    var body: some View {
        TabView(selection: $selection) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "star")
                }
                .tag(Tabs.advanced)
        }
        .padding(20)
        .frame(width: 375, height: 150)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("darkMode") private var darkMode = true
    
    var body: some View {
        Form {
            Toggle("Dark mode", isOn: $darkMode)
        }
    }
}

struct AdvancedSettingsView: View {
    var body: some View {
        Text("Advanced")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
