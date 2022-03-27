//
//  Enumerated.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/6/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

// 和 Sequence 里面的含义是完全一致的.
extension ObservableType {
    /*
     Enumerates the elements of an observable sequence.
     */
    public func enumerated()
    -> Observable<(index: Int, element: Element)> {
        Enumerated(source: self.asObservable())
    }
}

// 同 Sequence 的 Enumerate 一样. 为每一个 Ele, 增加了 Index, 变为了一个元组.
final private class EnumeratedSink<Element, Observer: ObserverType>: Sink<Observer>, ObserverType where Observer.Element == (index: Int, element: Element) {
    
    var index = 0
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            do {
                // 在自己的内部, 进行 idx 的建立.
                // 给后方的元组, 是 ele + index 的组合.
                let nextIndex = try incrementChecked(&self.index)
                let next = (index: nextIndex, element: value)
                self.forwardOn(.next(next))
            } catch let e {
                self.forwardOn(.error(e))
                self.dispose()
            }
        case .completed:
            self.forwardOn(.completed)
            self.dispose()
        case .error(let error):
            self.forwardOn(.error(error))
            self.dispose()
        }
    }
}

// Enumerated 就没有复写 subscribe 方法, 而是走了 Producer 的逻辑. 
final private class Enumerated<Element>: Producer<(index: Int, element: Element)> {
    private let source: Observable<Element>
    
    init(source: Observable<Element>) {
        self.source = source
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == (index: Int, element: Element) {
        let sink = EnumeratedSink<Element, Observer>(observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
