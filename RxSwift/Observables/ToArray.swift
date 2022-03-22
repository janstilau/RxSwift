//
//  ToArray.swift
//  RxSwift
//
//  Created by Junior B. on 20/10/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    
    // ToArray 返回的是一个 Single, 因为 ToArray 满足 Single 的特性.
    // 只会发射一次 next 到后方节点, 然后就是 Complete. 或者, 直接 Error.
    public func toArray()
    -> Single<[Element]> {
        // PrimitiveSequence 的 traint 是 single. 通过返回值的类型, 决定了 trait 的类型.
        PrimitiveSequence(raw: ToArray(source: self.asObservable()))
    }
}

final private class ToArraySink<SourceType, Observer: ObserverType>: Sink<Observer>, ObserverType where Observer.Element == [SourceType] {
    typealias Parent = ToArray<SourceType>
    
    let parent: Parent
    var list = [SourceType]()
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    // 在 On 方法里面不断的收集, 直到 complete 事件的时候, 一次性将所有的数据发送出去.
    func on(_ event: Event<SourceType>) {
        switch event {
        case .next(let value):
            // 收集的工作.
            self.list.append(value)
        case .error(let e):
            self.forwardOn(.error(e))
            self.dispose()
        case .completed:
            // 最终, 当 complete 来临的时候, 将所有的数据传递到后方的节点.
            self.forwardOn(.next(self.list))
            self.forwardOn(.completed)
            self.dispose()
        }
    }
}

final private class ToArray<SourceType>: Producer<[SourceType]> {
    let source: Observable<SourceType>
    
    init(source: Observable<SourceType>) {
        self.source = source
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == [SourceType] {
        let sink = ToArraySink(parent: self, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
