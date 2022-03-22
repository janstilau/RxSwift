//
//  SkipWhile.swift
//  RxSwift
//
//  Created by Yury Korolev on 10/9/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    
    //  Bypasses elements in an observable sequence as long as a specified condition is true and then returns the remaining elements.
    public func skip(while predicate: @escaping (Element) throws -> Bool) -> Observable<Element> {
        SkipWhile(source: self.asObservable(), predicate: predicate)
    }
}

final private class SkipWhileSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = SkipWhile<Element>
    
    private let parent: Parent
    private var running = false
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            // 同 Until 相比, 这个 Sink 存储的是一个 Block.
            // 所以, 每次 on 处理新的数据的时候, 先是用这个 block 进行判断, 当条件达到之后, 进行后续数据的处理, 并且不会再次进行判断了. 
            if !self.running {
                do {
                    self.running = try !self.parent.predicate(value)
                } catch let e {
                    self.forwardOn(.error(e))
                    self.dispose()
                    return
                }
            }
            
            if self.running {
                self.forwardOn(.next(value))
            }
        case .error, .completed:
            self.forwardOn(event)
            self.dispose()
        }
    }
}

final private class SkipWhile<Element>: Producer<Element> {
    typealias Predicate = (Element) throws -> Bool
    
    private let source: Observable<Element>
    fileprivate let predicate: Predicate
    
    init(source: Observable<Element>, predicate: @escaping Predicate) {
        self.source = source
        self.predicate = predicate
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = SkipWhileSink(parent: self, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
