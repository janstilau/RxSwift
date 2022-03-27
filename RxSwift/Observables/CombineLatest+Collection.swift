//
//  CombineLatest+Collection.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/29/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    
    public static func combineLatest<Collection: Swift.Collection>(
        _ collection: Collection,
        resultSelector: @escaping ([Collection.Element.Element]) throws -> Element)
    -> Observable<Element>
    // 非常重要的限制, Collection 里面, 必须要是一个 Publisher 才可以 .
    where Collection.Element: ObservableType {
        CombineLatestCollectionType(sources: collection, resultSelector: resultSelector)
    }
    
    public static func combineLatest<Collection: Swift.Collection>(_ collection: Collection) -> Observable<[Element]>
    where Collection.Element: ObservableType, Collection.Element.Element == Element {
        CombineLatestCollectionType(sources: collection, resultSelector: { $0 })
    }
}

/*
 这个类, 当做 CombineLast 的实现.
 上面的几个, 不通用.
 */
final private class CombineLatestCollectionTypeSink<Collection: Swift.Collection, Observer: ObserverType>
: Sink<Observer> where Collection.Element: ObservableConvertibleType {
    
    typealias Result = Observer.Element
    typealias Parent = CombineLatestCollectionType<Collection, Result>
    typealias SourceElement = Collection.Element.Element
    
    let parent: Parent
    
    let lock = RecursiveLock()
    
    // state
    var numberOfValues = 0
    var values: [SourceElement?]
    var isDone: [Bool]
    var numberOfDone = 0
    var subscriptions: [SingleAssignmentDisposable]
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        self.values = [SourceElement?](repeating: nil, count: parent.count)
        self.isDone = [Bool](repeating: false, count: parent.count)
        self.subscriptions = [SingleAssignmentDisposable]()
        self.subscriptions.reserveCapacity(parent.count)
        
        for _ in 0 ..< parent.count {
            self.subscriptions.append(SingleAssignmentDisposable())
        }
        
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<SourceElement>, atIndex: Int) {
        self.lock.lock(); defer { self.lock.unlock() }
        
        switch event {
        case .next(let element):
            // 只在第一次, 进行 numberOfValues 的更新.
            if self.values[atIndex] == nil {
                self.numberOfValues += 1
            }
            
            self.values[atIndex] = element
            
            // 只有全部有值了, 才向后续节点, 发射信号.
            if self.numberOfValues < self.parent.count {
                let numberOfOthersThatAreDone = self.numberOfDone - (self.isDone[atIndex] ? 1 : 0)
                if numberOfOthersThatAreDone == self.parent.count - 1 {
                    self.forwardOn(.completed)
                    self.dispose()
                }
                return
            }
            
            do {
                let result = try self.parent.resultSelector(self.values.map { $0! })
                self.forwardOn(.next(result))
            } catch let error {
                self.forwardOn(.error(error))
                self.dispose()
            }
            
        case .error(let error):
            self.forwardOn(.error(error))
            self.dispose()
        case .completed:
            if self.isDone[atIndex] {
                return
            }
            
            // Complete, 记录每个 Source 的 complete 的状态值. 
            self.isDone[atIndex] = true
            self.numberOfDone += 1
            
            if self.numberOfDone == self.parent.count {
                self.forwardOn(.completed)
                self.dispose()
            } else {
                self.subscriptions[atIndex].dispose()
            }
        }
    }
    
    func run() -> Disposable {
        var j = 0
        for i in self.parent.sources {
            let index = j
            let source = i.asObservable()
            // 使用循环, 把 sources 里面的所有 source 都进行了注册.
            let disposable = source.subscribe(AnyObserver { event in
                self.on(event, atIndex: index)
            })
            
            self.subscriptions[j].setDisposable(disposable)
            j += 1
        }
        
        // 如果, 根本就没有 soruce, 直接发射一个 next, 一个 complete.
        if self.parent.sources.isEmpty {
            do {
                let result = try self.parent.resultSelector([])
                self.forwardOn(.next(result))
                self.forwardOn(.completed)
                self.dispose()
            } catch let error {
                self.forwardOn(.error(error))
                self.dispose()
            }
        }
        
        return Disposables.create(subscriptions)
    }
}

final private class CombineLatestCollectionType<Collection: Swift.Collection, Result>: Producer<Result> where Collection.Element: ObservableConvertibleType {
    
    typealias ResultSelector = ([Collection.Element.Element]) throws -> Result
    
    let sources: Collection
    let resultSelector: ResultSelector
    let count: Int
    
    init(sources: Collection, resultSelector: @escaping ResultSelector) {
        self.sources = sources
        self.resultSelector = resultSelector
        self.count = self.sources.count
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Result {
        let sink = CombineLatestCollectionTypeSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}
