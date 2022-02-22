//
//  ObserverType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 官方文档, 说的很抽象. 发射个信号, 然后后面的观察者接收到信号触发各自的方法.
 对于信号发送, 只有 NotificationCenter 做到了信号发送的含义. 它将所有的注册监听, 信号发送收集到了自己的内部.
 
 对于传统的监听者模式来说, 就是将观察者的信息, 存储到被观察者的内部.
 这样, 发射信号, 其实就是找到自己存储的被观察者, 然后调用被观察者的方法.
 
 所以, subscribe 就是发送者存储观察者, on 就是发送者主动调用观察者的方法.
 
 不过, 这里由增加了一层抽象. 各种 Subscribe 返回的是一个 Producer, 里面按照不同的 Producer 的业务, 存储了需要的数据.
 真正的注册链条的节点, 是 Producer 产生的 Sink 对象.
 
 这样的设计, 也就导致了, 每次 subscribe 其实是造成了两条信号处理链条.
 */


/// Supports push-style iteration over an observable sequence.
public protocol ObserverType {
    /// The type of elements in sequence that observer can observe.
    associatedtype Element

    /// Notify observer about sequence event.
    ///
    /// - parameter event: Event that occurred.
    func on(_ event: Event<Element>)
}

/// Convenience API extensions to provide alternate next, error, completed events
extension ObserverType {
    
    /// Convenience method equivalent to `on(.next(element: Element))`
    ///
    /// - parameter element: Next element to send to observer(s)
    public func onNext(_ element: Element) {
        self.on(.next(element))
    }
    
    /// Convenience method equivalent to `on(.completed)`
    public func onCompleted() {
        self.on(.completed)
    }
    
    /// Convenience method equivalent to `on(.error(Swift.Error))`
    /// - parameter error: Swift.Error to send to observer(s)
    public func onError(_ error: Swift.Error) {
        self.on(.error(error))
    }
}
