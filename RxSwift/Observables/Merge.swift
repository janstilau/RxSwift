//
//  Merge.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    
    // 当上游发射一个信号来临之后, 可以生产出一个新的事件序列出来.
    public func flatMap<Source: ObservableConvertibleType>(
        _ selector: @escaping (Element) throws -> Source)
    -> Observable<Source.Element> {
        return FlatMap(source: self.asObservable(), selector: selector)
    }
    
}

extension ObservableType {
    
    /*
     Projects each element of an observable sequence to an observable sequence and merges the resulting observable sequences into one observable sequence.
     If element is received while there is some projected observable sequence being merged it will simply be ignored.
     */
    public func flatMapFirst<Source: ObservableConvertibleType>(_ selector: @escaping (Element) throws -> Source)
    -> Observable<Source.Element> {
        return FlatMapFirst(source: self.asObservable(), selector: selector)
    }
}

// 当, 自己的 ele 都是 Source 的时候, 可以直接调用 Merge
extension ObservableType where Element: ObservableConvertibleType {
    
    /*
     Merges elements from all observable sequences in the given enumerable sequence into a single observable sequence.
     */
    public func merge() -> Observable<Element.Element> {
        Merge(source: self.asObservable())
    }
    
    /**
     Merges elements from all inner observable sequences into a single observable sequence, limiting the number of concurrent subscriptions to inner sequences.
     */
    public func merge(maxConcurrent: Int)
    -> Observable<Element.Element> {
        MergeLimited(source: self.asObservable(), maxConcurrent: maxConcurrent)
    }
}

extension ObservableType where Element: ObservableConvertibleType {
    
    /**
     Concatenates all inner observable sequences, as long as the previous observable sequence terminated successfully.
     
     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)
     
     - returns: An observable sequence that contains the elements of each observed inner sequence, in sequential order.
     */
    public func concat() -> Observable<Element.Element> {
        self.merge(maxConcurrent: 1)
    }
}

extension ObservableType {
    /**
     Merges elements from all observable sequences from collection into a single observable sequence.
     
     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)
     
     - parameter sources: Collection of observable sequences to merge.
     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    public static func merge<Collection: Swift.Collection>(_ sources: Collection) -> Observable<Element> where Collection.Element == Observable<Element> {
        MergeArray(sources: Array(sources))
    }
    
    /**
     Merges elements from all observable sequences from array into a single observable sequence.
     
     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)
     
     - parameter sources: Array of observable sequences to merge.
     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    public static func merge(_ sources: [Observable<Element>]) -> Observable<Element> {
        MergeArray(sources: sources)
    }
    
    /**
     Merges elements from all observable sequences into a single observable sequence.
     
     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)
     
     - parameter sources: Collection of observable sequences to merge.
     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    public static func merge(_ sources: Observable<Element>...) -> Observable<Element> {
        MergeArray(sources: sources)
    }
}

// MARK: concatMap

extension ObservableType {
    /**
     Projects each element of an observable sequence to an observable sequence and concatenates the resulting observable sequences into one observable sequence.
     
     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)
     
     - returns: An observable sequence that contains the elements of each observed inner sequence, in sequential order.
     */
    
    public func concatMap<Source: ObservableConvertibleType>(_ selector: @escaping (Element) throws -> Source)
    -> Observable<Source.Element> {
        return ConcatMap(source: self.asObservable(), selector: selector)
    }
}

private final class MergeLimitedSinkIter<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>
: ObserverType
, LockOwnerType
, SynchronizedOnType where SourceSequence.Element == Observer.Element {
    typealias Element = Observer.Element
    typealias DisposeKey = CompositeDisposable.DisposeKey
    typealias Parent = MergeLimitedSink<SourceElement, SourceSequence, Observer>
    
    private let parent: Parent
    private let disposeKey: DisposeKey
    
    var lock: RecursiveLock {
        self.parent.lock
    }
    
    init(parent: Parent, disposeKey: DisposeKey) {
        self.parent = parent
        self.disposeKey = disposeKey
    }
    
    func on(_ event: Event<Element>) {
        self.synchronizedOn(event)
    }
    
    func synchronized_on(_ event: Event<Element>) {
        switch event {
        case .next:
            self.parent.forwardOn(event)
        case .error:
            self.parent.forwardOn(event)
            self.parent.dispose()
        case .completed:
            self.parent.group.remove(for: self.disposeKey)
            if let next = self.parent.queue.dequeue() {
                // 当, 自己完毕了, 会空出来一个位置, 所以一定是 activeCount < max, 所以直接就调用 self.parent.subscribe 将存储的 ele 拿出来开启新的注册了.
                self.parent.subscribe(next, group: self.parent.group)
            } else {
                self.parent.activeCount -= 1
                if self.parent.stopped && self.parent.activeCount == 0 {
                    self.parent.forwardOn(.completed)
                    self.parent.dispose()
                }
            }
        }
    }
}

private final class ConcatMapSink<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>: MergeLimitedSink<SourceElement, SourceSequence, Observer> where Observer.Element == SourceSequence.Element {
    typealias Selector = (SourceElement) throws -> SourceSequence
    
    private let selector: Selector
    
    init(selector: @escaping Selector, observer: Observer, cancel: Cancelable) {
        self.selector = selector
        super.init(maxConcurrent: 1, observer: observer, cancel: cancel)
    }
    
    // 要使用, 存储的 Selector 来生成新的 Source.
    override func performMap(_ element: SourceElement) throws -> SourceSequence {
        try self.selector(element)
    }
}

private final class MergeLimitedBasicSink<SourceSequence: ObservableConvertibleType, Observer: ObserverType>: MergeLimitedSink<SourceSequence, SourceSequence, Observer> where Observer.Element == SourceSequence.Element {
    
    override func performMap(_ element: SourceSequence) throws -> SourceSequence {
        element
    }
}

private class MergeLimitedSink<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>
: Sink<Observer>
, ObserverType where Observer.Element == SourceSequence.Element {
    typealias QueueType = Queue<SourceSequence>
    
    // 这个值, 控制的同时可以监听多少个 element 生成的事件序列.
    let maxConcurrent: Int
    
    let lock = RecursiveLock()
    
    // state
    var stopped = false
    var activeCount = 0
    var queue = QueueType(capacity: 2)
    
    let sourceSubscription = SingleAssignmentDisposable()
    let group = CompositeDisposable()
    
    init(maxConcurrent: Int, observer: Observer, cancel: Cancelable) {
        self.maxConcurrent = maxConcurrent
        super.init(observer: observer, cancel: cancel)
    }
    
    func run(_ source: Observable<SourceElement>) -> Disposable {
        _ = self.group.insert(self.sourceSubscription)
        
        let disposable = source.subscribe(self)
        self.sourceSubscription.setDisposable(disposable)
        return self.group
    }
    
    func subscribe(_ innerSource: SourceSequence, group: CompositeDisposable) {
        let subscription = SingleAssignmentDisposable()
        
        let key = group.insert(subscription)
        
        if let key = key {
            let observer = MergeLimitedSinkIter(parent: self, disposeKey: key)
            let disposable = innerSource.asObservable().subscribe(observer)
            subscription.setDisposable(disposable)
        }
    }
    
    func performMap(_ element: SourceElement) throws -> SourceSequence {
        rxAbstractMethod()
    }
    
    @inline(__always)
    final private func nextElementArrived(element: SourceElement) -> SourceSequence? {
        self.lock.performLocked {
            let subscribe: Bool
            if self.activeCount < self.maxConcurrent {
                self.activeCount += 1
                subscribe = true
            } else {
                do {
                    // 缓存起来. 缓存起来的, 是 ele 产生的 sequence, 不是 element.
                    let value = try self.performMap(element)
                    self.queue.enqueue(value)
                } catch {
                    self.forwardOn(.error(error))
                    self.dispose()
                }
                subscribe = false
            }
            
            if subscribe {
                do {
                    return try self.performMap(element)
                } catch {
                    self.forwardOn(.error(error))
                    self.dispose()
                }
            }
            
            return nil
        }
    }
    
    func on(_ event: Event<SourceElement>) {
        switch event {
        case .next(let element):
            if let sequence = self.nextElementArrived(element: element) {
                self.subscribe(sequence, group: self.group)
            }
        case .error(let error):
            self.lock.performLocked {
                self.forwardOn(.error(error))
                self.dispose()
            }
        case .completed:
            self.lock.performLocked {
                if self.activeCount == 0 {
                    self.forwardOn(.completed)
                    self.dispose()
                }
                else {
                    self.sourceSubscription.dispose()
                }
                
                self.stopped = true
            }
        }
    }
}

final private class MergeLimited<SourceSequence: ObservableConvertibleType>: Producer<SourceSequence.Element> {
    private let source: Observable<SourceSequence>
    private let maxConcurrent: Int
    
    init(source: Observable<SourceSequence>, maxConcurrent: Int) {
        self.source = source
        self.maxConcurrent = maxConcurrent
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceSequence.Element {
        let sink = MergeLimitedBasicSink<SourceSequence, Observer>(maxConcurrent: self.maxConcurrent, observer: observer, cancel: cancel)
        let subscription = sink.run(self.source)
        return (sink: sink, subscription: subscription)
    }
}

// MARK: Merge

private final class MergeBasicSink<Source: ObservableConvertibleType, Observer: ObserverType> : MergeSink<Source, Source, Observer> where Observer.Element == Source.Element {
    override func performMap(_ element: Source) throws -> Source {
        element
    }
}

// MARK: flatMap

private final class FlatMapSink<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType> :
    MergeSink<SourceElement, SourceSequence, Observer> where Observer.Element == SourceSequence.Element {
    typealias Selector = (SourceElement) throws -> SourceSequence
    
    private let selector: Selector
    
    init(selector: @escaping Selector, observer: Observer, cancel: Cancelable) {
        self.selector = selector
        super.init(observer: observer, cancel: cancel)
    }
    
    // 对于 FlatMap 来说, 就是使用存储的 Selector, 从一个 element 生成一个 Publisher
    override func performMap(_ element: SourceElement) throws -> SourceSequence {
        try self.selector(element)
    }
}

// MARK: FlatMapFirst

private final class FlatMapFirstSink<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType> : MergeSink<SourceElement, SourceSequence, Observer> where Observer.Element == SourceSequence.Element {
    typealias Selector = (SourceElement) throws -> SourceSequence
    
    private let selector: Selector
    
    override var subscribeNext: Bool {
        self.activeCount == 0
    }
    
    init(selector: @escaping Selector, observer: Observer, cancel: Cancelable) {
        self.selector = selector
        super.init(observer: observer, cancel: cancel)
    }
    
    override func performMap(_ element: SourceElement) throws -> SourceSequence {
        try self.selector(element)
    }
}

// 每一个 Sequence, 都注册给一个 MergeSinkIter 对象, 这个对象, 直接将数据传递给 MergeSink 对象.
private final class MergeSinkIter<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType> : ObserverType where Observer.Element == SourceSequence.Element {
    typealias Parent = MergeSink<SourceElement, SourceSequence, Observer>
    typealias DisposeKey = CompositeDisposable.DisposeKey
    typealias Element = Observer.Element
    
    private let parent: Parent
    private let disposeKey: DisposeKey
    
    init(parent: Parent, disposeKey: DisposeKey) {
        self.parent = parent
        self.disposeKey = disposeKey
    }
    
    // MergeSinkIter 就是直接将数据, 传递给后面的了.
    func on(_ event: Event<Element>) {
        self.parent.lock.performLocked {
            switch event {
            case .next(let value):
                self.parent.forwardOn(.next(value))
            case .error(let error):
                self.parent.forwardOn(.error(error))
                self.parent.dispose()
            case .completed:
                self.parent.group.remove(for: self.disposeKey)
                self.parent.activeCount -= 1
                self.parent.checkCompleted()
            }
        }
    }
}


// Concat 有着明确的前后顺序, Merge 就是监听, 各个序列哪一个先发生, 就向后面的节点, 发射哪个数据.

private class MergeSink<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>
: Sink<Observer>
, ObserverType where Observer.Element == SourceSequence.Element {
    
    typealias ResultType = Observer.Element
    typealias Element = SourceElement
    
    let lock = RecursiveLock()
    
    var subscribeNext: Bool {
        true
    }
    
    // state
    let group = CompositeDisposable()
    let sourceSubscription = SingleAssignmentDisposable()
    
    var activeCount = 0
    var stopped = false
    
    override init(observer: Observer, cancel: Cancelable) {
        super.init(observer: observer, cancel: cancel)
    }
    
    // 如何从 topLine Source 的每一个 element, 变化出一个 Publisher 出来.
    func performMap(_ element: SourceElement) throws -> SourceSequence {
        rxAbstractMethod()
    }
    
    // 这里就是生成 SubLine Publisher 的过程. 并且在这里进行了数量的管理.
    final private func nextElementArrived(element: SourceElement) -> SourceSequence? {
        self.lock.performLocked {
            // 这里控制着, 当 on 中来临了一个新的 ele 的时候, 应该如何处理.
            // 垃圾命名, 这里应该是 shouldSubscribeNext.
            // FlatFirst 在这里的处理逻辑就是, 只有当前没有 activeCount, 也就是没有 element 生成的 source 当前正在被处理的时候, 才会注册
            if !self.subscribeNext {
                return nil
            }
            do {
                let value = try self.performMap(element)
                self.activeCount += 1
                return value
            } catch let e {
                self.forwardOn(.error(e))
                self.dispose()
                return nil
            }
        }
    }
    
    func on(_ event: Event<SourceElement>) {
        switch event {
        case .next(let element):
            // 当, 源 Source 发射一个信号之后, 调用 nextElementArrived 来生成一个新的 Publisher.
            if let value = self.nextElementArrived(element: element) {
                // 新生成的 Publisher 的事件, 要直接传递给后续节点.
                self.subscribeInner(value.asObservable())
            }
        case .error(let error):
            self.lock.performLocked {
                self.forwardOn(.error(error))
                self.dispose()
            }
        case .completed:
            self.lock.performLocked {
                self.stopped = true
                self.sourceSubscription.dispose()
                self.checkCompleted()
            }
        }
    }
    
    func subscribeInner(_ source: Observable<Observer.Element>) {
        let iterDisposable = SingleAssignmentDisposable()
        if let disposeKey = self.group.insert(iterDisposable) {
            let iter = MergeSinkIter(parent: self, disposeKey: disposeKey)
            // 然后, 使用新生成的 Publisher, 注册一个 MergeSinkIter
            let subscription = source.subscribe(iter)
            iterDisposable.setDisposable(subscription)
        }
    }
    
    func run(_ sources: [Observable<Observer.Element>]) -> Disposable {
        self.activeCount += sources.count
        
        for source in sources {
            self.subscribeInner(source)
        }
        
        self.stopped = true
        
        self.checkCompleted()
        
        return self.group
    }
    
    // self.stopped 代表着, source 没有数据了.
    // self.activeCount 代表着, 各个 ele 生成的 Publisher 也都没有数据了.
    func checkCompleted() {
        if self.stopped && self.activeCount == 0 {
            self.forwardOn(.completed)
            self.dispose()
        }
    }
    
    func run(_ source: Observable<SourceElement>) -> Disposable {
        _ = self.group.insert(self.sourceSubscription)
        
        let subscription = source.subscribe(self)
        self.sourceSubscription.setDisposable(subscription)
        
        return self.group
    }
}

// MARK: Producers

final private class FlatMap<SourceElement, SourceSequence: ObservableConvertibleType>: Producer<SourceSequence.Element> {
    typealias Selector = (SourceElement) throws -> SourceSequence
    
    private let source: Observable<SourceElement>
    
    private let selector: Selector
    
    init(source: Observable<SourceElement>, selector: @escaping Selector) {
        self.source = source
        self.selector = selector
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceSequence.Element {
        
        let sink = FlatMapSink(selector: self.selector, observer: observer, cancel: cancel)
        let subscription = sink.run(self.source)
        return (sink: sink, subscription: subscription)
    }
}

final private class FlatMapFirst<SourceElement, SourceSequence: ObservableConvertibleType>: Producer<SourceSequence.Element> {
    typealias Selector = (SourceElement) throws -> SourceSequence
    
    private let source: Observable<SourceElement>
    
    private let selector: Selector
    
    init(source: Observable<SourceElement>, selector: @escaping Selector) {
        self.source = source
        self.selector = selector
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceSequence.Element {
        let sink = FlatMapFirstSink<SourceElement, SourceSequence, Observer>(selector: self.selector, observer: observer, cancel: cancel)
        let subscription = sink.run(self.source)
        return (sink: sink, subscription: subscription)
    }
}

final class ConcatMap<SourceElement, SourceSequence: ObservableConvertibleType>: Producer<SourceSequence.Element> {
    typealias Selector = (SourceElement) throws -> SourceSequence
    
    private let source: Observable<SourceElement>
    private let selector: Selector
    
    init(source: Observable<SourceElement>, selector: @escaping Selector) {
        self.source = source
        self.selector = selector
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceSequence.Element {
        let sink = ConcatMapSink<SourceElement, SourceSequence, Observer>(selector: self.selector, observer: observer, cancel: cancel)
        let subscription = sink.run(self.source)
        return (sink: sink, subscription: subscription)
    }
}

final class Merge<SourceSequence: ObservableConvertibleType> : Producer<SourceSequence.Element> {
    private let source: Observable<SourceSequence>
    
    init(source: Observable<SourceSequence>) {
        self.source = source
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceSequence.Element {
        let sink = MergeBasicSink<SourceSequence, Observer>(observer: observer, cancel: cancel)
        let subscription = sink.run(self.source)
        return (sink: sink, subscription: subscription)
    }
}

final private class MergeArray<Element>: Producer<Element> {
    private let sources: [Observable<Element>]
    
    init(sources: [Observable<Element>]) {
        self.sources = sources
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = MergeBasicSink<Observable<Element>, Observer>(observer: observer, cancel: cancel)
        let subscription = sink.run(self.sources)
        return (sink: sink, subscription: subscription)
    }
}
