//
//  DistinctUntilChanged.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType where Element: Equatable {
    
    public func distinctUntilChanged()
    -> Observable<Element> {
        self.distinctUntilChanged({ $0 }, comparer: { ($0 == $1) })
    }
}

extension ObservableType {
    /*
     Returns an observable sequence that contains only distinct contiguous elements according to the `keySelector`.
     */
    public func distinctUntilChanged<Key: Equatable>(_ keySelector: @escaping (Element) throws -> Key)
    -> Observable<Element> {
        self.distinctUntilChanged(keySelector, comparer: { $0 == $1 })
    }
    
    /*
     Returns an observable sequence that contains only distinct contiguous elements according to the `comparer`.
     */
    public func distinctUntilChanged(_ comparer: @escaping (Element, Element) throws -> Bool)
    -> Observable<Element> {
        // key selector 就是 返回 自己.
        self.distinctUntilChanged({ $0 }, comparer: comparer)
    }
    
    /*
     Returns an observable sequence that contains only distinct contiguous elements according to the keySelector and the comparer.
     */
    // 这是最最核心的方法, 如何取值, 取得值后, 如何进行判断.
    // 其他的最终都归结到该方法.
    public func distinctUntilChanged<K>(_ keySelector: @escaping (Element) throws -> K,
                                        comparer: @escaping (K, K) throws -> Bool)
    -> Observable<Element> {
        return DistinctUntilChanged(source: self.asObservable(), selector: keySelector, comparer: comparer)
    }
    
    /*
     Returns an observable sequence that contains only contiguous elements with distinct values in the provided key path on each object.
     */
    public func distinctUntilChanged<Property: Equatable>(at keyPath: KeyPath<Element, Property>) ->
    Observable<Element> {
        self.distinctUntilChanged { $0[keyPath: keyPath] == $1[keyPath: keyPath] }
    }
}

/*
 DistinctUntilChangedSink 并没有在 subscribe 的时候, 有什么新的操作.
 仅仅是在 on 的时候, 增加了取值, 判等的逻辑.
 */
final private class DistinctUntilChangedSink<Observer: ObserverType, Key>: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element
    
    private let parent: DistinctUntilChanged<Element, Key>
    private var currentKey: Key?
    
    init(parent: DistinctUntilChanged<Element, Key>, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    // On 里面的逻辑就很简单, 比对不相等, 才会发射新的信号.
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            do {
                // 这里可以当做是, 代码的典范.
                let key = try self.parent.selector(value)
                var areEqual = false
                if let currentKey = self.currentKey {
                    areEqual = try self.parent.comparer(currentKey, key)
                }
                
                if areEqual {
                    return
                }
                
                // 存储一下最新的不同的 key 值.
                self.currentKey = key
                // 然后直接交给后方节点.
                self.forwardOn(event)
            } catch let error {
                self.forwardOn(.error(error))
                self.dispose()
            }
        case .error, .completed:
            self.forwardOn(event)
            self.dispose()
        }
    }
}

final private class DistinctUntilChanged<Element, Key>: Producer<Element> {
    typealias KeySelector = (Element) throws -> Key
    typealias EqualityComparer = (Key, Key) throws -> Bool
    
    private let source: Observable<Element>
    fileprivate let selector: KeySelector // 这个存储的, 如何从 Value 里面, 抽取要比较的 Property
    fileprivate let comparer: EqualityComparer // 这个存储的, 如何比较 Property
    
    init(source: Observable<Element>, selector: @escaping KeySelector, comparer: @escaping EqualityComparer) {
        self.source = source
        self.selector = selector
        self.comparer = comparer
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = DistinctUntilChangedSink(parent: self, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
