//
//  Lock.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/31/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol Lock {
    func lock()
    func unlock()
}

typealias SpinLock = RecursiveLock

extension RecursiveLock : Lock {
    // Final 的含义是 ???
    // 这种, 根据返回值来确定泛型类型的技巧, 在 Swift 里面, 用的非常非常多.
    // 是一种通用的设计思路. 
    final func performLocked<T>(_ action: () -> T) -> T {
        self.lock(); defer { self.unlock() }
        return action()
    }
}
