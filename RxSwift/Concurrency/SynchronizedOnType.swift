//
//  SynchronizedOnType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 SynchronizedOnType 的要求就是, 可以在线程安全的情况下, 执行某些操作.
 而实现则是, 使用自己的锁进行加锁, 解锁. 然后在锁环境下, 进行这些操作. 
 */
protocol SynchronizedOnType: AnyObject, ObserverType, Lock {
    func synchronized_on(_ event: Event<Element>)
}

// 将, 线程同步的逻辑封装起来, 子类只用实现 synchronized_on 的方法就可以了
extension SynchronizedOnType {
    func synchronizedOn(_ event: Event<Element>) {
        self.lock(); defer { self.unlock() }
        self.synchronized_on(event)
    }
}
