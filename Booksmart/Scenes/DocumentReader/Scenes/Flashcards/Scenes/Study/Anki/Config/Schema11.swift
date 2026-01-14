//
//  Schema11.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 05/01/23.
//

import Foundation

/*
/// These items are expected to exist in schema 11. When adding
/// new config variables, you do not need to add them here -
/// just create an accessor function in one of the config*.rs files,
/// with an appropriate default for missing/invalid values instead.
pub(crate) fn schema11_config_as_string(creation_offset: Option<i32>) -> String {
    let obj = json!({
        "activeDecks": [1],
        "curDeck": 1,
        "newSpread": 0,
        "collapseTime": 1200,
        "timeLim": 0,
        "estTimes": true,
        "dueCounts": true,
        "curModel": null,
        "nextPos": 1,
        "sortType": "noteFld",
        "sortBackwards": false,
        "addToCur": true,
        "dayLearnFirst": false,
        "schedVer": 2,
        "creationOffset": creation_offset,
    });
    serde_json::to_string(&obj).unwrap()
}
*/

final class conf {
    // In mod.rs, collapseTime is used in enum ConfigKey. Looks like it's LearnAheadSecs with default value of 1200. Guess it's safe to define it as constant.
    static let collapseTime: Int = 1200
}
