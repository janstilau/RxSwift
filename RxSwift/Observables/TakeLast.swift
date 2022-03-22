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
    
    // 在内部, 使用一个 queue 来记录.
    private var elements: Queue<Element>
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        self.elements = Queue<Element>(capacity: parent.count + 1)
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            // 当, next 来临的时候, 进行存储, 进行 buffer size 的控制.
            self.elements.enqueue(value)
            // 如果, 超过了 Buffer 的个数, 会有一个置换的处理.
            if self.elements.count > self.parent.count {
                _ = self.elements.dequeue()
            }
        case .error:
            self.forwardOn(event)
            self.dispose()
        case .completed:
            // 在, 结束的时候, 将存储的所有值一次性的进行发送. 
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
