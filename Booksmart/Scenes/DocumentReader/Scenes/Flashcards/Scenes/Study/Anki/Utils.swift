//
//  Utils.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 05/01/23.
//

import Foundation
import RealmSwift

final class utils {
    // # Time handling
    // ##############################################################################
    
    static func int_time(scale: Int = 1) -> Int {
        /*
         def int_time(scale: int = 1) -> int:
            "The time in integer seconds. Pass scale=1000 to get milliseconds."
            return int(time.time() * scale)
         */
        let timeInterval = Time.time() * scale
        return timeInterval
    }

    // # IDs
    // ##############################################################################
    static func ids2str(ids: [ObjectId]) -> String {
        /*
        def ids2str(ids: Iterable[int | str]) -> str:
            """Given a list of integers, return a string '(int1,int2,...)'."""
            return f"({','.join(str(i) for i in ids)})"
        */
        ids.map({ $0.stringValue }).joined(separator: ",")
    }
}

final class Time {
    static func time() -> Int {
        // Notes:
        // In Python, time.time() gets the current time in seconds since the epoch.
        // TODO: Check if the below typecast will result in loss of data.
        Int(Date().timeIntervalSince1970)
    }
}
