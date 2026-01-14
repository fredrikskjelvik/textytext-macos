//import Foundation
//
//protocol HasUserDefaultsManager {
//    var userDefaults: UserDefaultsManager { get }
//}
//
//protocol HasUrlSession {
//    var urlSession: URLSession { get }
//}
//
//protocol HasAPIService {
//    var apiService: APIService { get }
//}
//
//protocol HasRealmManager {
//    var realm: RealmManager { get }
//}
//
//struct Dependencies: HasUserDefaultsManager, HasUrlSession, HasAPIService, HasRealmManager {
//    let userDefaults: UserDefaultsManager
//    let urlSession: URLSession
//    let apiService: APIService
//    let realm: RealmManager
//
//    init(
//        userDefaults: UserDefaultsManager = .standard,
//        urlSession: URLSession = .shared,
//        apiService: APIService,
//        realm: RealmManager
//    ) {
//        self.userDefaults = userDefaults
//        self.urlSession = urlSession
//        self.apiService = apiService
//        self.realm = realm
//    }
//
//    static let production = Dependencies(apiService: APIServiceProduction(), realm: RealmManager())
//    static let testing = Dependencies(apiService: APIServiceTesting(), realm: RealmManager())
//}
// https://github.com/hmlongco/Factory


import Foundation
import Factory
import RealmSwift

extension Container {
    static let userDefaults = Factory<UserDefaultsManager>(scope: .singleton) { UserDefaultsManager.standard }
    static let urlSession = Factory<URLSession>(scope: .singleton) { URLSession.shared }
    static let apiService = Factory<APIService>(scope: .shared) { APIServiceProduction() }
    static let realm = Factory<Realm>(scope: .singleton) { RealmManager().realm }
}

