//
//  TakeLast.swift
//  RxSwift
//
//  Created by Tomi Koskinen on 25/10/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    
    // 只发最后的几个.
    /*
     You can emit only the final n items emitted by an Observable and ignore those items that come before them, by modifying the Observable with the TakeLast operator.
     */
    /*
     Returns a specified number of contiguous elements from the end of an observable sequence.
     */
    public func takeLast(_ count: Int)
    -> Observable<Element> {
        TakeLast(source: self.asObservable(), count: count)
    }
}

final private class TakeLastSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    
    typealias Element = Observer.Element
    typealias Parent = TakeLast<Element>
    
    private let parent: Parent
    
    // Queue, 用来缓存.
    private var elements: Queue<Element>
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        self.elements = Queue<Element>(capacity: parent.count + 1)
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            self.elements.enqueue(value)
            // 如果, 超过了 Buffer 的个数, 会有一个置换的处理. 
            if self.elements.count > self.parent.count {
                _ = self.elements.dequeue()
            }
        case .error:
            self.forwardOn(event)
            self.dispose()
        case .completed:
            for e in self.elements {
                self.forwardOn(.next(e))
            }
            self.forwardOn(.completed)
            self.dispose()
        }
    }
}

final private class TakeLast<Element>: Producer<Element> {
    private let source: Observable<Element>
    fileprivate let count: Int
    
    init(source: Observable<Element>, count: Int) {
        if count < 0 {
            rxFatalError("count can't be negative")
        }
        self.source = source
        self.count = count
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = TakeLastSink(parent: self, observer: observer, cancel: cancel)
        // 没有特殊的操作, 直接进行 subscribe.
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
