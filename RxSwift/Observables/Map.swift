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
    
    private let transform: Transform
    
    init(transform: @escaping Transform, observer: Observer, cancel: Cancelable) {
        self.transform = transform
        super.init(observer: observer, cancel: cancel)
    }
    
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
    
    // 各种 Sink 类里面, run 的逻辑, 几乎是一样的.
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == ResultType {
        let sink = MapSink(transform: self.transform, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
