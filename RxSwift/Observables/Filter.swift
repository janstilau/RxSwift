//
//  Filter.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/17/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    public func filter(_ predicate: @escaping (Element) throws -> Bool)
    -> Observable<Element> {
        Filter(source: self.asObservable(), predicate: predicate)
    }
}

extension ObservableType {
    // 为什么要这面复杂, 一个 next 里面不会做任何操作的 Sink 不更加的简单明了吗.
    public func ignoreElements()
    -> Observable<Never> {
        self.flatMap { _ in Observable<Never>.empty() }
    }
}

final private class FilterSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Predicate = (Element) throws -> Bool
    typealias Element = Observer.Element
    
    private let predicate: Predicate
    
    init(predicate: @escaping Predicate, observer: Observer, cancel: Cancelable) {
        self.predicate = predicate
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            do {
                let satisfies = try self.predicate(value)
                // 只有, 符合了 Filter 的过滤条件的信号, 才会参与到后面的信号处理中.
                // 如果不符合 Filter 的要求, 那么其实信号在这里就会中断了. 
                if satisfies {
                    self.forwardOn(.next(value))
                }
            } catch let e {
                self.forwardOn(.error(e))
                self.dispose()
            }
        case .completed, .error:
            self.forwardOn(event)
            self.dispose()
        }
    }
}

final private class Filter<Element>: Producer<Element> {
    typealias Predicate = (Element) throws -> Bool
    
    private let source: Observable<Element>
    private let predicate: Predicate
    
    init(source: Observable<Element>, predicate: @escaping Predicate) {
        self.source = source
        self.predicate = predicate
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = FilterSink(predicate: self.predicate, observer: observer, cancel: cancel)
        // Filter 所有的逻辑, 都在 Sink 内部, 是在 on 函数里面进行处理.
        // 所以, 它不需要一个专门的 run 方法.
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
