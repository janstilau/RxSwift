//
//  ObservableType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 
 This pattern facilitates concurrent operations because it does not need to block while waiting for the Observable to emit objects, but instead it creates a sentry in the form of an observer that stands ready to react appropriately at whatever future time the Observable does so.
 这里, 官方的文档讲的很明白, Observer 是作为, Publisher emit 信号后的相应处理哨兵存在的.
 
 Rather than calling a method, you define a mechanism for retrieving and transforming the data, in the form of an “Observable,” and then subscribe an observer to it, at which point the previously-defined mechanism fires into action with the observer standing sentry to capture and respond to its emissions whenever they are ready.
 */

/// Represents a push style sequence.
public protocol ObservableType: ObservableConvertibleType {
    /**
    Subscribes `observer` to receive events for this sequence.
    
    ### Grammar
    
    **Next\* (Error | Completed)?**
    
    * sequences can produce zero or more elements so zero or more `Next` events can be sent to `observer`
    * once an `Error` or `Completed` event is sent, the sequence terminates and can't produce any other elements
    
     这里其实保证了, 信号只会发送一次, 不会在两个线程同时发送信号.  其实两个线程, 同时发送信号才是一个复杂的事情.
    It is possible that events are sent from different threads, but no two events can be sent concurrently to
    `observer`.
    
    ### Resource Management
    
     一定, 要厘清内存管理相关的事情.
     1. 如果, 接收到了 Complete Event, 那么这个节点应该清除自己的内存.
     2. 如果, 接收到了 dispose, 那么这个节点应该清除自己的内存.
     对于优先的 sequence, 就算不把返回的 subscription 添加到 Bag 里面, 当 Complete 事件发送的时候, 相关的资源也是会正常的清楚的.
     但是, 对于无限的 Sequence, 如果不主动地进行 dispose, 那么这个序列, 会一直发送信号.
     一般来说, 各个节点内部, 会有循环引用来保持这个节点的生命周期, 只有当 dispose, 或者 complete event 到达的时候, 才会主动地打破这层循环引用, 来释放节点.
    When sequence sends `Complete` or `Error` event all internal resources that compute sequence elements
    will be freed.
    
    To cancel production of sequence elements and free resources immediately, call `dispose` on returned
    subscription.
    
    - returns: Subscription for `observer` that can be used to cancel production of sequence elements and free resources.
    */
    func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element
}

extension ObservableType {
    
    /// Default implementation of converting `ObservableType` to `Observable`.
    public func asObservable() -> Observable<Element> {
        // temporary workaround
        //return Observable.create(subscribe: self.subscribe)
        Observable.create { o in self.subscribe(o) }
    }
}
