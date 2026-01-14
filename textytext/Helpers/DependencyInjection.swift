import Foundation
import Factory
import RealmSwift

extension Container {
    static let userDefaults = Factory<UserDefaultsManager>(scope: .singleton) { UserDefaultsManager.standard }
    static let urlSession = Factory<URLSession>(scope: .singleton) { URLSession.shared }
    static let realm = Factory<Realm>(scope: .singleton) { RealmManager().realm }
}

