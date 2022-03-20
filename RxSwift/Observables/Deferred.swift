//
//  Deferred.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    /*
     Returns an observable sequence that invokes the specified factory function whenever a new observer subscribes.
     */
    public static func deferred(_ observableFactory:
                                @escaping () throws -> Observable<Element>)
    -> Observable<Element> {
        Deferred(observableFactory: observableFactory)
    }
}

// 这就是一个中间节点. 
final private class DeferredSink<Source: ObservableType, Observer: ObserverType>: Sink<Observer>, ObserverType where Source.Element == Observer.Element {
    typealias Element = Observer.Element
    
    private let observableFactory: () throws -> Source
    
    init(observableFactory: @escaping () throws -> Source, observer: Observer, cancel: Cancelable) {
        self.observableFactory = observableFactory
        super.init(observer: observer, cancel: cancel)
    }
    
    func run() -> Disposable {
        do {
            let result = try self.observableFactory()
            // 自己产生一个 Publisher, 然后自己注册给 Publisher.
            return result.subscribe(self)
        } catch let e {
            self.forwardOn(.error(e))
            self.dispose()
            return Disposables.create()
        }
    }
    
    // 纯粹的一个中介者.
    func on(_ event: Event<Element>) {
        self.forwardOn(event)
        
        switch event {
        case .next:
            break
        case .error:
            self.dispose()
        case .completed:
            self.dispose()
        }
    }
}

final private class Deferred<Source: ObservableType>: Producer<Source.Element> {
    typealias Factory = () throws -> Source
    
    private let observableFactory : Factory
    
    init(observableFactory: @escaping Factory) {
        self.observableFactory = observableFactory
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable)
    where Observer.Element == Source.Element {
        let sink = DeferredSink(observableFactory: self.observableFactory, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}
