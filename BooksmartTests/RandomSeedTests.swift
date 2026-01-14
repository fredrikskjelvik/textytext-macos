//
//  RandomSeedTests.swift
//  BooksmartTests
//
//  Created by Felix Marianayagam on 06/01/23.
//

import XCTest
@testable import Booksmart

final class RandomSeedTests: XCTestCase {

    func testExample() throws {
        var random = Random(seed: 123)
        // For the given list and seed, the random number generated remains the same.
        let result = Int.random(in: 0..<100, using: &random)
        XCTAssert(result == 27)
    }

}
