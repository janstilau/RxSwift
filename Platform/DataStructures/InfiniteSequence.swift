//
//  InfiniteSequence.swift
//  Platform
//
//  Created by Krunoslav Zaher on 6/13/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 Repeat 一定次数的 Sequence.
 */
struct InfiniteSequence<Element> : Sequence {
    
    typealias Iterator = AnyIterator<Element>
    
    private let repeatedValue: Element
    
    init(repeatedValue: Element) {
        self.repeatedValue = repeatedValue
    }
    
    func makeIterator() -> Iterator {
        let repeatedValue = self.repeatedValue
        return AnyIterator { repeatedValue }
    }
}
