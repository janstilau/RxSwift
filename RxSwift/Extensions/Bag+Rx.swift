//
//  Bag+Rx.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/19/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//


// MARK: forEach

/*
 对于 Bag 逻辑的处理.
 以下的逻辑, 是完完全全建立在, 对于 Bag 的实现细节清楚明白的基础上的.
 */
@inline(__always)
func dispatch<Element>(_ bag: Bag<(Event<Element>) -> Void>, _ event: Event<Element>) {
    // Bag 里面, 存储的元素, 应该是一个接受 Event 数据的闭包表达式
    bag._value0?(event)

    if bag._onlyFastPath {
        return
    }

    let pairs = bag._pairs
    for i in 0 ..< pairs.count {
        pairs[i].value(event)
    }

    if let dictionary = bag._dictionary {
        for element in dictionary.values {
            element(event)
        }
    }
}

/// Dispatches `dispose` to all disposables contained inside bag
/*
 disposeAll 的处理逻辑, 和 dispatch 没有任何区别. 不过是 Bag 里面存储的数据类型不同.
 */
func disposeAll(in bag: Bag<Disposable>) {
    bag._value0?.dispose()

    if bag._onlyFastPath {
        return
    }

    let pairs = bag._pairs
    for i in 0 ..< pairs.count {
        pairs[i].value.dispose()
    }

    if let dictionary = bag._dictionary {
        for element in dictionary.values {
            element.dispose()
        }
    }
}
