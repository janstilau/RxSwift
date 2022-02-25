//
//  LockOwnerType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 LockOwnerType 的唯一要求, 就是自己要有一把锁.
 */

protocol LockOwnerType: AnyObject, Lock {
    var lock: RecursiveLock { get }
}

extension LockOwnerType {
    func lock() { self.lock.lock() }
    func unlock() { self.lock.unlock() }
}
