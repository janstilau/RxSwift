//
//  ElementAt.swift
//  RxSwift
//
//  Created by Junior B. on 21/10/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    public func element(at index: Int)
    -> Observable<Element> {
        ElementAt(source: self.asObservable(), index: index, throwOnEmpty: true)
    }
}

final private class ElementAtSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias SourceType = Observer.Element
    typealias Parent = ElementAt<SourceType>
    
    let parent: Parent
    var i: Int
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        self.i = parent.index
        
        super.init(observer: observer, cancel: cancel)
    }
    
    // 在 on 中, 进行了 times 的判断.
    func on(_ event: Event<SourceType>) {
        switch event {
        case .next:
            
            if self.i == 0 {
                // 当, 到达了想要的 Index 之后, 发射给后面的节点, 然后发射 compelte 事件.
                self.forwardOn(event)
                self.forwardOn(.completed)
                self.dispose()
            }
            
            do {
                _ = try decrementChecked(&self.i)
            } catch let e {
                self.forwardOn(.error(e))
                self.dispose()
                return
            }
            
        case .error(let e):
            self.forwardOn(.error(e))
            self.dispose()
        case .completed:
            // 能够直接接收到 Complete, 那就是 self.i 没有能够到达 0
            // 那么就不符合 elementAt 的定义, 代表着 source count 到达不了 index.
            if self.parent.throwOnEmpty {
                self.forwardOn(.error(RxError.argumentOutOfRange))
            } else {
                self.forwardOn(.completed)
            }
            
            self.dispose()
        }
    }
}

final private class ElementAt<SourceType>: Producer<SourceType> {
    let source: Observable<SourceType>
    let throwOnEmpty: Bool
    let index: Int
    
    init(source: Observable<SourceType>, index: Int, throwOnEmpty: Bool) {
        self.source = source
        self.index = index
        self.throwOnEmpty = throwOnEmpty
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceType {
        let sink = ElementAtSink(parent: self, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
