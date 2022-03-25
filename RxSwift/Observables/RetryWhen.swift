//
//  RetryWhen.swift
//  RxSwift
//
//  Created by Junior B. on 06/10/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    /*
     Repeats the source observable sequence on error when the notifier emits a next value.
     If the source observable errors and the notifier completes, it will complete the source sequence.
     
     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)
     
     - parameter notificationHandler: A handler that is passed an observable sequence of errors raised by the source observable and returns and observable that either continues, completes or errors. This behavior is then applied to the source observable.
     - returns: An observable sequence producing the elements of the given sequence repeatedly until it terminates successfully or is notified to error or complete.
     */
    public func retry<TriggerObservable: ObservableType, Error: Swift.Error>(when notificationHandler: @escaping (Observable<Error>) -> TriggerObservable)
    -> Observable<Element> {
        RetryWhenSequence(sources: InfiniteSequence(repeatedValue: self.asObservable()),
                          notificationHandler: notificationHandler)
    }
    
    /**
     Repeats the source observable sequence on error when the notifier emits a next value.
     If the source observable errors and the notifier completes, it will complete the source sequence.
     
     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)
     
     - parameter notificationHandler: A handler that is passed an observable sequence of errors raised by the source observable and returns and observable that either continues, completes or errors. This behavior is then applied to the source observable.
     - returns: An observable sequence producing the elements of the given sequence repeatedly until it terminates successfully or is notified to error or complete.
     */
    public func retry<TriggerObservable: ObservableType>(when notificationHandler: @escaping (Observable<Swift.Error>) -> TriggerObservable)
    -> Observable<Element> {
        RetryWhenSequence(sources: InfiniteSequence(repeatedValue: self.asObservable()),
                          notificationHandler: notificationHandler)
    }
}

final private class RetryTriggerSink<Sequence: Swift.Sequence, Observer: ObserverType, TriggerObservable: ObservableType, Error>
: ObserverType where Sequence.Element: ObservableType, Sequence.Element.Element == Observer.Element {
    typealias Element = TriggerObservable.Element
    
    typealias Parent = RetryWhenSequenceSinkIter<Sequence, Observer, TriggerObservable, Error>
    
    private let parent: Parent
    
    init(parent: Parent) {
        self.parent = parent
    }
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            self.parent.parent.lastError = nil
            self.parent.parent.schedule(.moveNext)
        case .error(let e):
            self.parent.parent.forwardOn(.error(e))
            self.parent.parent.dispose()
        case .completed:
            self.parent.parent.forwardOn(.completed)
            self.parent.parent.dispose()
        }
    }
}

final private class RetryWhenSequenceSinkIter<Sequence: Swift.Sequence, Observer: ObserverType, TriggerObservable: ObservableType, Error>
: ObserverType
, Disposable where Sequence.Element: ObservableType, Sequence.Element.Element == Observer.Element {
    typealias Element = Observer.Element
    typealias Parent = RetryWhenSequenceSink<Sequence, Observer, TriggerObservable, Error>
    
    fileprivate let parent: Parent
    private let errorHandlerSubscription = SingleAssignmentDisposable()
    private let subscription: Disposable
    
    init(parent: Parent, subscription: Disposable) {
        self.parent = parent
        self.subscription = subscription
    }
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            // 正常, 直接流转给后方
            self.parent.forwardOn(event)
        case .error(let error):
            // 记录一下错误值.
            self.parent.lastError = error
            
            if let failedWith = error as? Error {
                // dispose current subscription
                self.subscription.dispose()
                
                // 在 Rx 里面, 这种一次性的事件序列使用的很频繁.
                // 因为在 Rx 里面, 一切都是用信号的方式进行处理的, 所以一些中间的机制, 也是使用的临时事件序列.
                // 这里, 让下一个 error 来临是, 又产生了一个新的 RetryTriggerSink, 当做 notifier 的监听者. 之前的 RetryTriggerSink 会在 errorHandlerSubscription.setDisposable 的逻辑里面, 被 dispose 掉.
                let errorHandlerSubscription = self.parent.notifier.subscribe(RetryTriggerSink(parent: self))
                self.errorHandlerSubscription.setDisposable(errorHandlerSubscription)
                // 在这里, 使用 errorSubject 接受了当前的错误值.
                self.parent.errorSubject.on(.next(failedWith))
            } else {
                // 没看明白这里.
                self.parent.forwardOn(.error(error))
                self.parent.dispose()
            }
        case .completed:
            // 完成, 直接流转给后方.
            self.parent.forwardOn(event)
            self.parent.dispose()
        }
    }
    
    final func dispose() {
        self.subscription.dispose()
        self.errorHandlerSubscription.dispose()
    }
}

final private class RetryWhenSequenceSink<Sequence: Swift.Sequence, Observer: ObserverType, TriggerObservable: ObservableType, Error>
: TailRecursiveSink<Sequence, Observer> where Sequence.Element: ObservableType, Sequence.Element.Element == Observer.Element {
    
    typealias Element = Observer.Element
    typealias Parent = RetryWhenSequence<Sequence, TriggerObservable, Error>
    
    let lock = RecursiveLock()
    
    private let parent: Parent
    
    fileprivate var lastError: Swift.Error?
    fileprivate let errorSubject = PublishSubject<Error>()
    private let handler: Observable<TriggerObservable.Element>
    fileprivate let notifier = PublishSubject<TriggerObservable.Element>()
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        self.handler = parent.notificationHandler(self.errorSubject).asObservable()
        super.init(observer: observer, cancel: cancel)
    }
    
    override func done() {
        if let lastError = self.lastError {
            self.forwardOn(.error(lastError))
            self.lastError = nil
        }
        else {
            self.forwardOn(.completed)
        }
        
        self.dispose()
    }
    
    override func extract(_ observable: Observable<Element>) -> SequenceGenerator? {
        // It is important to always return `nil` here because there are side effects in the `run` method
        // that are dependant on particular `retryWhen` operator so single operator stack can't be reused in this
        // case.
        return nil
    }
    
    // 这里的 Source, 就是上游节点, Retry When 里面的 事件序列 Collection, 是 repeatedCollection.
    override func subscribeToNext(_ source: Observable<Element>) -> Disposable {
        let subscription = SingleAssignmentDisposable()
        // 将需要 retry 的上游节点, 和 RetryWhenSequenceSinkIter 进行了挂钩.
        let iter = RetryWhenSequenceSinkIter(parent: self, subscription: subscription)
        subscription.setDisposable(source.subscribe(iter))
        return iter
    }
    
    override func run(_ sources: SequenceGenerator) -> Disposable {
        // self.handler 和 self.notifier 挂钩.
        let triggerSubscription = self.handler.subscribe(self.notifier.asObserver())
        let superSubscription = super.run(sources)
        return Disposables.create(superSubscription, triggerSubscription)
    }
}

final private class RetryWhenSequence<Sequence: Swift.Sequence, TriggerObservable: ObservableType, Error>: Producer<Sequence.Element.Element> where Sequence.Element: ObservableType {
    typealias Element = Sequence.Element.Element
    
    private let sources: Sequence
    fileprivate let notificationHandler: (Observable<Error>) -> TriggerObservable
    
    init(sources: Sequence, notificationHandler: @escaping (Observable<Error>) -> TriggerObservable) {
        self.sources = sources
        self.notificationHandler = notificationHandler
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = RetryWhenSequenceSink<Sequence, Observer, TriggerObservable, Error>(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run((self.sources.makeIterator(), nil))
        return (sink: sink, subscription: subscription)
    }
}
