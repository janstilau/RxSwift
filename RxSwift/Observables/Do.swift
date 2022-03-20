//
//  Do.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    /*
     Invokes an action for each event in the observable sequence, and propagates all observer messages through the result sequence.
     */
    public func `do`(onNext: ((Element) throws -> Void)? = nil, afterNext: ((Element) throws -> Void)? = nil, onError: ((Swift.Error) throws -> Void)? = nil, afterError: ((Swift.Error) throws -> Void)? = nil, onCompleted: (() throws -> Void)? = nil, afterCompleted: (() throws -> Void)? = nil, onSubscribe: (() -> Void)? = nil, onSubscribed: (() -> Void)? = nil, onDispose: (() -> Void)? = nil)
    -> Observable<Element> {
        /*
         和惯例一样, 这种单一的函数, 就是构建 Producer 的过程. 真正的在响应链条里面起作用的, 还是各个 Sink 节点.
         */
        return Do(source: self.asObservable(), eventHandler: { e in
            switch e {
            case .next(let element):
                try onNext?(element)
            case .error(let e):
                try onError?(e)
            case .completed:
                try onCompleted?()
            }
        }, afterEventHandler: { e in
            switch e {
            case .next(let element):
                try afterNext?(element)
            case .error(let e):
                try afterError?(e)
            case .completed:
                try afterCompleted?()
            }
        }, onSubscribe: onSubscribe, onSubscribed: onSubscribed, onDispose: onDispose)
    }
}

final private class DoSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element
    typealias EventHandler = (Event<Element>) throws -> Void
    typealias AfterEventHandler = (Event<Element>) throws -> Void
    
    private let eventHandler: EventHandler
    private let afterEventHandler: AfterEventHandler
    
    init(eventHandler: @escaping EventHandler, afterEventHandler: @escaping AfterEventHandler, observer: Observer, cancel: Cancelable) {
        self.eventHandler = eventHandler
        self.afterEventHandler = afterEventHandler
        super.init(observer: observer, cancel: cancel)
    }
    
    // Do 没有进行任何的信号的加工, 就是直接 Forward 到后续节点.
    // 在 Forward 的前后, 调用注册的方法.
    func on(_ event: Event<Element>) {
        do {
            try self.eventHandler(event)
            self.forwardOn(event)
            try self.afterEventHandler(event)
            if event.isStopEvent {
                self.dispose()
            }
        }
        catch let error {
            self.forwardOn(.error(error))
            self.dispose()
        }
    }
}

final private class Do<Element>: Producer<Element> {
    typealias EventHandler = (Event<Element>) throws -> Void
    typealias AfterEventHandler = (Event<Element>) throws -> Void
    
    private let source: Observable<Element>
    private let eventHandler: EventHandler
    private let afterEventHandler: AfterEventHandler
    private let onSubscribe: (() -> Void)?
    private let onSubscribed: (() -> Void)?
    private let onDispose: (() -> Void)?
    
    init(source: Observable<Element>, eventHandler: @escaping EventHandler, afterEventHandler: @escaping AfterEventHandler, onSubscribe: (() -> Void)?, onSubscribed: (() -> Void)?, onDispose: (() -> Void)?) {
        self.source = source
        self.eventHandler = eventHandler
        self.afterEventHandler = afterEventHandler
        self.onSubscribe = onSubscribe
        self.onSubscribed = onSubscribed
        self.onDispose = onDispose
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        self.onSubscribe?()
        let sink = DoSink(eventHandler: self.eventHandler, afterEventHandler: self.afterEventHandler, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        // 在 Subscribe 之后, 调用存储的 onSubscribed
        self.onSubscribed?()
        let onDispose = self.onDispose
        // onDispose 之所以可以被使用, 是因为被包装了一层.
        // 这也是面向接口的好处, 一个包装体, 在外界看来, 仅仅是一个接口对象.
        let allSubscriptions = Disposables.create {
            subscription.dispose()
            onDispose?()
        }
        return (sink: sink, subscription: allSubscriptions)
    }
}
