//
//  Random.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 06/01/23.
//

import Foundation

struct Random: RandomNumberGenerator {
    init(seed: Int) { srand48(seed) }
    func next() -> UInt64 { return UInt64(drand48() * Double(UInt64.max)) }
}
// when deployed used seed: Int.random(in: 0..<Int.max)
