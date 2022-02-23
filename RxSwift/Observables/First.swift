//
//  First.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 7/31/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

private final class FirstSink<Element, Observer: ObserverType> : Sink<Observer>, ObserverType where Observer.Element == Element? {
    typealias Parent = First<Element>
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            // 如果有数据, 发送整个数据之后, 立马就发送 complte 并且 dispose 了.
            self.forwardOn(.next(value))
            self.forwardOn(.completed)
            self.dispose()
        case .error(let error):
            self.forwardOn(.error(error))
            self.dispose()
        case .completed:
            // 如果没有数据, 就发送一个 nil 回去.
            self.forwardOn(.next(nil))
            self.forwardOn(.completed)
            self.dispose()
        }
    }
}

final class First<Element>: Producer<Element?> {
    private let source: Observable<Element>
    
    init(source: Observable<Element>) {
        self.source = source
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element? {
        let sink = FirstSink(observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
