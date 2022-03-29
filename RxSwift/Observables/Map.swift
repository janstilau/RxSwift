//
//  Map.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    
    /*
     Projects each element of an observable sequence into a new form.
     */
    public func map<Result>(_ transform: @escaping (Element) throws -> Result)
    -> Observable<Result> {
        Map(source: self.asObservable(), transform: transform)
    }
}

final private class MapSink<SourceType, Observer: ObserverType>: Sink<Observer>, ObserverType {
    
    // 各种 typealias 让类内部的处理, 变得简单.
    // 这是一个值的学习的编码技巧.
    typealias Transform = (SourceType) throws -> ResultType
    typealias ResultType = Observer.Element
    typealias Element = SourceType
    
    // 在内部存储了如何变化的闭包. 
    private let transform: Transform
    
    init(transform: @escaping Transform, observer: Observer, cancel: Cancelable) {
        self.transform = transform
        super.init(observer: observer, cancel: cancel)
    }
    
    // 处理上方信号, 得到值之后, map 进行 transform, 然后 forward
    func on(_ event: Event<SourceType>) {
        switch event {
        case .next(let element):
            do {
                let mappedElement = try self.transform(element)
                self.forwardOn(.next(mappedElement))
            } catch let e {
                self.forwardOn(.error(e))
                // 对于 Sink 来说, dispose 1. 关闭自己的循环引用. 2 将自己的 self.disposed 设置为 1, 这样 Sink 就不会给后续节点传输数据了. 
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
    
    // 各种 Sink 类里面, run 的逻辑, 几乎是一样的.
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable)
    -> (sink: Disposable, subscription: Disposable) where Observer.Element == ResultType {
        // MapSink 创建的时候, 将后续的 Observer, 和 MapSink 进行了关联.
        // MAPSink 的前方节点传递数据给 MapSink 之后, 会触发 MapSink 的 Transform 逻辑, 然后把结果, 传递给后面的 Observer
        let sink = MapSink(transform: self.transform, observer: observer, cancel: cancel)
        // 然后, 会将 MapSink 和前方的 source 进行关联.
        // source.subscribe 中, 又会将 source 创建出来的 Sink, 和 MapSink 进行关联.
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
