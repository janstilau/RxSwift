//
//  Dematerialize.swift
//  RxSwift
//
//  Created by Jamie Pinkham on 3/13/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

extension ObservableType where Element: EventConvertible {
    /*
     Convert any previously materialized Observable into it's original form.
     */
    public func dematerialize() -> Observable<Element.Element> {
        Dematerialize(source: self.asObservable())
    }
}

private final class DematerializeSink<T: EventConvertible, Observer: ObserverType>: Sink<Observer>, ObserverType where Observer.Element == T.Element {
    fileprivate func on(_ event: Event<T>) {
        switch event {
        case .next(let element):
            self.forwardOn(element.event)
            // 还是原封传递. 只不过如果 event 是错误的, 就 dispose.
            if element.event.isStopEvent {
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

final private class Dematerialize<T: EventConvertible>: Producer<T.Element> {
    private let source: Observable<T>

    init(source: Observable<T>) {
        self.source = source
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == T.Element {
        let sink = DematerializeSink<T, Observer>(observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
