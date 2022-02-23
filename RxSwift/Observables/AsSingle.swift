//
//  AsSingle.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

private final class AsSingleSink<Observer: ObserverType> : Sink<Observer>, ObserverType {
    typealias Element = Observer.Element
    
    private var element: Event<Element>?
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            if self.element != nil {
                // 如果接收到了多个 element, 发送一个错误的信号到下游.
                self.forwardOn(.error(RxError.moreThanOneElement))
                self.dispose()
            }
            
            self.element = event
        case .error:
            self.forwardOn(event)
            self.dispose()
        case .completed:
            // 这种情况, 只能是, 一次 next, 一次 complete 才可以发生. 
            if let element = self.element {
                self.forwardOn(element)
                self.forwardOn(.completed)
            } else {
                self.forwardOn(.error(RxError.noElements))
            }
            self.dispose()
        }
    }
}

final class AsSingle<Element>: Producer<Element> {
    private let source: Observable<Element>
    
    init(source: Observable<Element>) {
        self.source = source
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = AsSingleSink(observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
