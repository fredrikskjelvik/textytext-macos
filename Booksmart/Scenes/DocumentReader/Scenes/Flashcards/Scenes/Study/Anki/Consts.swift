//
//  Consts.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 05/01/23.
//

import Foundation

enum CardQueue: Int {
    // # Queue types
    /*
    CardQueue = NewType("CardQueue", int)
    QUEUE_TYPE_MANUALLY_BURIED = CardQueue(-3)
    QUEUE_TYPE_SIBLING_BURIED = CardQueue(-2)
    QUEUE_TYPE_SUSPENDED = CardQueue(-1)
    QUEUE_TYPE_NEW = CardQueue(0)
    QUEUE_TYPE_LRN = CardQueue(1)
    QUEUE_TYPE_REV = CardQueue(2)
    QUEUE_TYPE_DAY_LEARN_RELEARN = CardQueue(3)
    QUEUE_TYPE_PREVIEW = CardQueue(4)
    */
    case QUEUE_TYPE_MANUALLY_BURIED = -3
    case QUEUE_TYPE_SIBLING_BURIED = -2
    case QUEUE_TYPE_SUSPENDED = -1
    case QUEUE_TYPE_NEW = 0
    case QUEUE_TYPE_LRN = 1
    case QUEUE_TYPE_REV = 2
    case QUEUE_TYPE_DAY_LEARN_RELEARN = 3
    case QUEUE_TYPE_PREVIEW = 4
}
