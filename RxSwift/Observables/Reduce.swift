//
//  Reduce.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/1/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 具有同样的函数名, 和 Sequence 的 Reduce 具有差不多相同的逻辑.
 */

extension ObservableType {
    public func reduce<A, Result>(_ seed: A,
                                  accumulator: @escaping (A, Element) throws -> A,
                                  mapResult: @escaping (A) throws -> Result)
    -> Observable<Result> {
        Reduce(source: self.asObservable(), seed: seed, accumulator: accumulator, mapResult: mapResult)
    }
    
    public func reduce<A>(_ seed: A, accumulator: @escaping (A, Element) throws -> A)
    -> Observable<A> {
        Reduce(source: self.asObservable(), seed: seed, accumulator: accumulator, mapResult: { $0 })
    }
}

final private class ReduceSink<SourceType, AccumulateType, Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias ResultType = Observer.Element
    typealias Parent = Reduce<SourceType, AccumulateType, ResultType>
    
    private let parent: Parent
    private var accumulation: AccumulateType // 存储, 最终的结果, 在开始的情况下, 是 seed 的值.
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        self.accumulation = parent.seed
        
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<SourceType>) {
        switch event {
        case .next(let value):
            do {
                // 每次 next 事件里面, 对于新传入的值进行累加, 然后进行存储.
                self.accumulation = try self.parent.accumulator(self.accumulation, value)
            } catch let e {
                self.forwardOn(.error(e))
                self.dispose()
            }
        case .error(let e):
            self.forwardOn(.error(e))
            self.dispose()
        case .completed:
            do {
                // 在, 最终接收到上游的 complete 事件之后, 将结果发送给下游, 然后发送 complete 事件.
                // 然后 dispose.
                let result = try self.parent.mapResult(self.accumulation)
                self.forwardOn(.next(result))
                self.forwardOn(.completed)
                self.dispose()
            }
            catch let e {
                self.forwardOn(.error(e))
                self.dispose()
            }
        }
    }
}

final private class Reduce<SourceType, AccumulateType, ResultType>: Producer<ResultType> {
    typealias AccumulatorType = (AccumulateType, SourceType) throws -> AccumulateType
    typealias ResultSelectorType = (AccumulateType) throws -> ResultType
    
    private let source: Observable<SourceType>
    fileprivate let seed: AccumulateType
    fileprivate let accumulator: AccumulatorType
    fileprivate let mapResult: ResultSelectorType
    
    init(source: Observable<SourceType>, seed: AccumulateType, accumulator: @escaping AccumulatorType, mapResult: @escaping ResultSelectorType) {
        self.source = source
        self.seed = seed
        self.accumulator = accumulator
        self.mapResult = mapResult
    }
    
    // Producer 存储的 source, subscribe 给新生成的 sink. 由 sink 来接受所有的时间序列上的值.
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == ResultType {
        let sink = ReduceSink(parent: self, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}

