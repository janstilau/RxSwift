//
//  SkipUntil.swift
//  RxSwift
//
//  Created by Yury Korolev on 10/3/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    // Returns the elements from the source observable sequence that are emitted after the other observable sequence produces an element.
    // 只有在 other 之后, 才会进行数据的传递.
    public func skip<Source: ObservableType>(until other: Source)
    -> Observable<Element> {
        SkipUntil(source: self.asObservable(), other: other.asObservable())
    }
}

final private class SkipUntilSinkOther<Other, Observer: ObserverType>
: ObserverType
, LockOwnerType
, SynchronizedOnType {
    typealias Parent = SkipUntilSink<Other, Observer>
    typealias Element = Other
    
    private let parent: Parent
    
    var lock: RecursiveLock {
        self.parent.lock
    }
    
    let subscription = SingleAssignmentDisposable()
    
    init(parent: Parent) {
        self.parent = parent
    }
    
    func on(_ event: Event<Element>) {
        self.synchronizedOn(event)
    }
    
    func synchronized_on(_ event: Event<Element>) {
        switch event {
        case .next:
            // 在这里, 对于另外的一个, 实际进行 Source 监听的 Sink 进行了状态改变.
            self.parent.forwardElements = true
            self.subscription.dispose()
        case .error(let e):
            self.parent.forwardOn(.error(e))
            self.parent.dispose()
        case .completed:
            self.subscription.dispose()
        }
    }
}


final private class SkipUntilSink<Other, Observer: ObserverType>
: Sink<Observer>
, ObserverType
, LockOwnerType
, SynchronizedOnType {
    
    typealias Element = Observer.Element
    typealias Parent = SkipUntil<Element, Other>
    
    let lock = RecursiveLock()
    private let parent: Parent
    // 专门的一个值, 来记录当前是否应该进行数据的 forward.
    fileprivate var forwardElements = false
    
    private let sourceSubscription = SingleAssignmentDisposable()
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<Element>) {
        self.synchronizedOn(event)
    }
    
    func synchronized_on(_ event: Event<Element>) {
        switch event {
        case .next:
            // 只有 forwardElements 的时候, 才进行数据的传递.
            if self.forwardElements {
                self.forwardOn(event)
            }
        case .error:
            self.forwardOn(event)
            self.dispose()
        case .completed:
            // ???
            if self.forwardElements {
                self.forwardOn(event)
            }
            self.dispose()
        }
    }
    
    func run() -> Disposable {
        let sourceSubscription = self.parent.source.subscribe(self)
        
        // 引入了一个中间层, 这个中间层, 来进行控制变量的值进行变化.
        // 所以, 这里有两个响应链路.
        let otherObserver = SkipUntilSinkOther(parent: self)
        let otherSubscription = self.parent.other.subscribe(otherObserver)
        
        self.sourceSubscription.setDisposable(sourceSubscription)
        otherObserver.subscription.setDisposable(otherSubscription)
        // 返回的 subscription, 应该取消当前的主链条的 sub, 以及 until 的 sub.
        return Disposables.create(sourceSubscription, otherObserver.subscription)
    }
}

final private class SkipUntil<Element, Other>: Producer<Element> {
    
    fileprivate let source: Observable<Element>
    fileprivate let other: Observable<Other>
    
    init(source: Observable<Element>, other: Observable<Other>) {
        self.source = source
        self.other = other
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = SkipUntilSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}
