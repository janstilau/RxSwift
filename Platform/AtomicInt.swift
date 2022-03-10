//
//  AtomicInt.swift
//  Platform
//
//  Created by Krunoslav Zaher on 10/28/18.
//  Copyright © 2018 Krunoslav Zaher. All rights reserved.
//

import Foundation

/*
 iOS 里面, 没有 Atomic 相关的数据类型.
 自我实现一个 Atomic Int.
 */

// 个人感觉, 应该是里面有一个锁, 而不是自己是一个锁.
final class AtomicInt: NSLock {
    fileprivate var value: Int32
    public init(_ value: Int32 = 0) {
        self.value = value
    }
}

/*
 以下方法都是一个函数.
 作者故意将 AtomicInt 命名为 this.
 */
/*
 在 AtomicInt 的锁环境下, 进行 Int 值的更改.
 更新新值, 返回旧值, 这是一个常见的设计方案.
 
 Atomic 的意义就在于, 将成员变量, 和所绑定在一起了, 无论在哪个线程进行这个成员变量的修改, 都会在锁的环境.
 相比较下, 类里面有一个锁, 然后用这个锁进行类内所有相关数据的修改, 这是一个需要程序员精心策划的过程, 稍有不慎, 就导致锁的滥用, 将不相干的数据, 用一把锁进行互斥.
 */
func add(_ this: AtomicInt, _ value: Int32) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.value += value
    this.unlock()
    return oldValue
}

func sub(_ this: AtomicInt, _ value: Int32) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.value -= value
    this.unlock()
    return oldValue
}

// 原值进行 Or 操作更改, 返回旧值.
func fetchOr(_ this: AtomicInt, _ mask: Int32) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.value |= mask
    this.unlock()
    return oldValue
}

// 取原值, 不做任何的修改.
func load(_ this: AtomicInt) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.unlock()
    return oldValue
}

// ++
func increment(_ this: AtomicInt) -> Int32 {
    add(this, 1)
}
// --
func decrement(_ this: AtomicInt) -> Int32 {
    sub(this, 1)
}

// 只是取值的时候加锁, & 运算不进行加锁.
func isFlagSet(_ this: AtomicInt, _ mask: Int32) -> Bool {
    (load(this) & mask) != 0
}
