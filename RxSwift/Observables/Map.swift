//
//  Map.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {

    /**
     Projects each element of an observable sequence into a new form.

     - seealso: [map operator on reactivex.io](http://reactivex.io/documentation/operators/map.html)

     - parameter transform: A transform function to apply to each source element.
     - returns: An observable sequence whose elements are the result of invoking the transform function on each element of source.

     */
    public func map<Result>(_ transform: @escaping (Element) throws -> Result)
        -> Observable<Result> {
        Map(source: self.asObservable(), transform: transform)
    }
}

final private class MapSink<SourceType, Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Transform = (SourceType) throws -> ResultType

    typealias ResultType = Observer.Element 
    typealias Element = SourceType

    private let transform: Transform

    init(transform: @escaping Transform, observer: Observer, cancel: Cancelable) {
        self.transform = transform
        super.init(observer: observer, cancel: cancel)
    }

    // 所有的相应链条节点, 当接收到 CompelteEvent 的时候, 都要进行自我的 dispose.
    // Map 的主要逻辑, 就是在 next 信号里面, 将数据进行转化, 然后交给后续的节点. 就是 self.forwardOn(.next(mappedElement)) 所做的事情.
    // 其他的事件, 则是原封的进行 forward
    func on(_ event: Event<SourceType>) {
        switch event {
        case .next(let element):
            do {
                let mappedElement = try self.transform(element)
                self.forwardOn(.next(mappedElement))
            } catch let e {
                self.forwardOn(.error(e))
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

final private class Map<SourceType, ResultType>: Producer<ResultType> {
    typealias Transform = (SourceType) throws -> ResultType

    private let source: Observable<SourceType>

    private let transform: Transform

    // Producer 里面, 仅仅是做相关值的存储.
    init(source: Observable<SourceType>, transform: @escaping Transform) {
        self.source = source
        self.transform = transform
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == ResultType {
        /*
         cancel 就是一个 sinkDisposer
         新生的 Sink 和 sinkDisposer 循环引用, 保证了 Sink 的生命周期.
         source.subscribe(sink), 上一个 source 生成的 sinkDisposer, 被保存到当前的 sinkDisposer 中作为 subscription
         而 sinkDisposer 的 dispose 逻辑, 是 sink dispose, 然后保存的 subscription dispose.
         这样, 最后一次注册的 subscription 的 dispose 操作, 会向上回溯, 将联调的所有节点, 都进行 dispose.
         */
        let sink = MapSink(transform: self.transform, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
