//
//  Scan.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    
    /*
     Applies an accumulator function over an observable sequence and returns each intermediate result. The specified seed value is used as the initial accumulator value.
     */
    // Seed 是初始值, 然后, Source 每发出一个信号, 就使用 accumulator 将存储的 result 和 信号值进行计算, 发送给后续的 observer
    // 并且将计算出来的 result, 进行存储.
    public func scan<A>(into seed: A, accumulator: @escaping (inout A, Element) throws -> Void)
    -> Observable<A> {
        Scan(source: self.asObservable(), seed: seed, accumulator: accumulator)
    }
    
    /**
     Applies an accumulator function over an observable sequence and returns each intermediate result. The specified seed value is used as the initial accumulator value.
     
     For aggregation behavior with no intermediate results, see `reduce`.
     
     - seealso: [scan operator on reactivex.io](http://reactivex.io/documentation/operators/scan.html)
     
     - parameter seed: The initial accumulator value.
     - parameter accumulator: An accumulator function to be invoked on each element.
     - returns: An observable sequence containing the accumulated values.
     */
    public func scan<A>(_ seed: A, accumulator: @escaping (A, Element) throws -> A)
    -> Observable<A> {
        return Scan(source: self.asObservable(), seed: seed) { acc, element in
            let currentAcc = acc
            acc = try accumulator(currentAcc, element)
        }
    }
}

// 对于这种内部类, 并不需要把所有的数据都进行存储.
// 它是不会在别的地方进行复用的.
// 直接, 使用成员变量进行引用, 然后使用对应的类型, 调用相关的方法就好了.
// 在 RxSwift 的实现里面, 这样的设计很多.
final private class ScanSink<Element, Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Accumulate = Observer.Element
    typealias Parent = Scan<Element, Accumulate>
    
    private let parent: Parent
    private var accumulate: Accumulate
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        self.accumulate = parent.seed
        super.init(observer: observer, cancel: cancel)
    }
    
    // 在每次接收到事件之后, 进行 accumulate 之后, 立马将这个值交给下游节点.
    // scan 会输出和原始序列相同个数的事件.
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let element):
            do {
                // 在 next 里面, 进行了累加并且存储的工作.
                // 然后, 将数据传递到下游的节点.
                try self.parent.accumulator(&self.accumulate, element)
                self.forwardOn(.next(self.accumulate))
            } catch let error {
                self.forwardOn(.error(error))
                self.dispose()
            }
        case .error(let error):
            self.forwardOn(.error(error))
            self.dispose()
        case .completed:
            self.forwardOn(.completed)
            self.dispose()
        }
    }
    
}

// Producer, 仅仅是做值的缓存, 真正的添加到响应序列里面的, 是各个 Sink 对象.
final private class Scan<Element, Accumulate>: Producer<Accumulate> {
    typealias Accumulator = (inout Accumulate, Element) throws -> Void
    
    private let source: Observable<Element>
    fileprivate let seed: Accumulate
    fileprivate let accumulator: Accumulator
    
    init(source: Observable<Element>, seed: Accumulate, accumulator: @escaping Accumulator) {
        self.source = source
        self.seed = seed
        self.accumulator = accumulator
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Accumulate {
        let sink = ScanSink(parent: self, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
