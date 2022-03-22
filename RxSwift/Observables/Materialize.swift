//
//  Materialize.swift
//  RxSwift
//
//  Created by sergdort on 08/03/2017.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    /*
     Convert any Observable into an Observable of its events.
     */
    // 将原来的 Element 变为了 Event<Element>, 这样这个序列就永远不会有错误的事情发生了.
    public func materialize() -> Observable<Event<Element>> {
        Materialize(source: self.asObservable())
    }
}

private final class MaterializeSink<Element, Observer: ObserverType>: Sink<Observer>, ObserverType where Observer.Element == Event<Element> {
    
    func on(_ event: Event<Element>) {
        self.forwardOn(.next(event))
        if event.isStopEvent {
            self.forwardOn(.completed)
            self.dispose()
        }
    }
}

final private class Materialize<T>: Producer<Event<T>> {
    private let source: Observable<T>
    
    init(source: Observable<T>) {
        self.source = source
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = MaterializeSink(observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        
        return (sink: sink, subscription: subscription)
    }
}
