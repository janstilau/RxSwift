//
//  LockOwnerType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// 太多的抽象了, 让最终呈现的代码复杂难懂. 
protocol LockOwnerType: AnyObject, Lock {
    var lock: RecursiveLock { get }
}

extension LockOwnerType {
    func lock() { self.lock.lock() }
    func unlock() { self.lock.unlock() }
}
