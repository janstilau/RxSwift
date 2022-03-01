//
//  Create.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    // MARK: create
    
    /**
     Creates an observable sequence from a specified subscribe method implementation.
     
     - seealso: [create operator on reactivex.io](http://reactivex.io/documentation/operators/create.html)
     
     - parameter subscribe: Implementation of the resulting observable sequence's `subscribe` method.
     - returns: The observable sequence with the specified implementation for the `subscribe` method.
     */
    
    // 这个返回的 Disposable 对象, 也不是实际获取使用的. 他会存储到最后的 Disposable 对象的内部.
    // 当最后一个 Disposable 对象调用 dispose 的时候, 会触发 create 返回的 Disposable 对象 .
    public static func create(_ subscribe: @escaping (AnyObserver<Element>) -> Disposable) -> Observable<Element> {
        AnonymousObservable(subscribe)
    }
}

final private class AnonymousObservableSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    
    typealias Element = Observer.Element
    typealias Parent = AnonymousObservable<Element>
    
    // state
    private let isStopped = AtomicInt(0)
    
#if DEBUG
    private let synchronizationTracker = SynchronizationTracker()
#endif
    
    override init(observer: Observer, cancel: Cancelable) {
        super.init(observer: observer, cancel: cancel)
    }
    
    // 这里, 实现 on 的意义就在于, parent.subscribeHandler(AnyObserver(self))
    // 也就是 create 传入的闭包, 是作用到了 AnonymousObservableSink 上面了, 只不过他把所有的 event, forward 给了自己记录的 Observer 了.
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            if load(self.isStopped) == 1 {
                return
            }
            self.forwardOn(event)
        case .error, .completed:
            if fetchOr(self.isStopped, 1) == 0 {
                self.forwardOn(event)
                self.dispose()
            }
        }
    }
    
    func run(_ parent: Parent) -> Disposable {
        parent.subscribeHandler(AnyObserver(self))
    }
}

final private class AnonymousObservable<Element>: Producer<Element> {
    
    typealias SubscribeHandler = (AnyObserver<Element>) -> Disposable
    
    let subscribeHandler: SubscribeHandler
    
    init(_ subscribeHandler: @escaping SubscribeHandler) {
        self.subscribeHandler = subscribeHandler
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = AnonymousObservableSink(observer: observer, cancel: cancel)
        // 这是信号源头, 所以没有 Source, 也就没有 Source 的 Subscribe 的操作.
        let subscription = sink.run(self)
        return (sink: sink, subscription: subscription)
    }
}
