//
//  Single.swift
//  RxSwift
//
//  Created by sergdort on 19/08/2017.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

#if DEBUG
import Foundation
#endif

/// Sequence containing exactly 1 element
/// 必须要有一个, 不能直接 Complete.
public enum SingleTrait { }
/// Represents a push style sequence containing 1 element.
public typealias Single<Element> = PrimitiveSequence<SingleTrait, Element>
public typealias SingleEvent<Element> = Result<Element, Swift.Error>

/*
 这种在 C++ 中也有对应的编译技巧.
 一个泛型类里面, 有一个 trait 类型. 这个类型, 不会真正的用到代码逻辑里面, 仅仅是用作类型判断. 当有这个类型是什么类型的时候, 该泛型类会有对应的方法.
 在这里, 这个泛型类是 PrimitiveSequenceType, PrimitiveSequence 在泛型类上面添加方法, 这些方法, 仅仅在 Trait 为某种类型的时候, 才能够使用.
 public typealias Single<Element> = PrimitiveSequence<SingleTrait, Element> 就是在做类型绑定的事情.
 
 泛型的两种用途,
 1. 抽象算法, 这种抽象算法是通过通用算法和接口实现的. 只要类型参数是对应的接口实现就可以.
 2. 类型绑定. 泛型是一个半成品, 只有真正的确定了所有的类型参数, 才能真正投入使用. 通过 typealias, 子类化, 将类型绑定了之后, 通用算法的返回值可以确定下来, 通用算法在使用的时候, 能够更加的便利.
 也可以使用特化技巧, 将某些通用算法限定在特定的类型参数下才可以使用, 这就是下面的几个函数的作用. 他们本来是定义在 PrimitiveSequenceType 之上的, 但是只能在 Single 上使用, 因为 Single 中, 绑定了 Trait 的值.
 */

extension PrimitiveSequenceType where Trait == SingleTrait {
    
    public typealias SingleObserver = (SingleEvent<Element>) -> Void
    
    /*
     Creates an observable sequence from a specified subscribe method implementation.
     */
    public static func create(subscribe: @escaping (@escaping SingleObserver) -> Disposable) -> Single<Element> {
        
        /*
         Single.create { singleObserver in
                开启异步操作 {
                singleObserver(.success("呵呵哒"))
            }
             return Disposables.create()
         }.subscribe { event in
             print(event)
         }
         
         
         这种, 参数是一个闭包, 参数闭包的参数也是一个闭包的应该怎么理解.
         
         参数是一个闭包, 参数闭包的参数是普通值, 代表这个闭包是一个回调, 是对方流程的某个阶段, 应该调用这个闭包来触发调用者的回调.
         
         参数是一个闭包, 参数闭包的参数也是一个闭包, 这个闭包, 还是一个回调, 对方流程的某个阶段应该调用这个闭包来触发调用者的回调. 这是正确的, 调用者的闭包, 是新建立一个 Publisher, 这是在接收到信号之后才做的.
         这个闭包的参数, 还是一个闭包. 代表着, 被调用者需要调用者主动调用这个闭包, 来触发自己的逻辑.
         A -> B with A 闭包, 是希望 B 调用 A 闭包, 来完成 A 的回调.
         A -> B with A 闭包, A 闭包的参数是 B 闭包, 是 B 在调用 A 闭包的时候, 希望 A 调用 B 闭包, 来触发 B 的逻辑 .
         在这里, B 调用 subscribe, 触发 A 的回调, A 的回调是创建一个新的 Publisher, 然后 A 的 Publisher 需要主动调用自己的参数闭包, 来触发 B 的逻辑. B 的逻辑就是, 根据 A 传入的 Result 的值, 触发 observer 的后续.
         
         那在这里就是, Observable<Element>.create 创建了一个 AnonymousObservableSink 中间节点, 这个中间节点接收到信号之后, 会回调 A 的闭包, 在 A 那里创建一个 Publisher.
         A 创建的 Publisher, 应该在合适的时机触发 B 闭包, B 闭包会触发 AnonymousObservableSink 的 on 事件, 将数据向后传递.
         */
        let source = Observable<Element>.create { observer in
            return subscribe { event in
                switch event {
                case .success(let element):
                    observer.on(.next(element))
                    observer.on(.completed)
                case .failure(let error):
                    observer.on(.error(error))
                }
            }
        }
        
        return PrimitiveSequence(raw: source)
    }
    
    /*
     Subscribes `observer` to receive events for this sequence.
     */
    public func subscribe(_ observer: @escaping (SingleEvent<Element>) -> Void) -> Disposable {
        var stopped = false
        return self.primitiveSequence.asObservable().subscribe { event in
            if stopped { return }
            stopped = true
            
            switch event {
            case .next(let element):
                observer(.success(element))
            case .error(let error):
                observer(.failure(error))
            case .completed:
                rxFatalErrorInDebug("Singles can't emit a completion event")
            }
        }
    }
    
    /**
     Subscribes a success handler, and an error handler for this sequence.
     
     Also, take in an object and provide an unretained, safe to use (i.e. not implicitly unwrapped), reference to it along with the events emitted by the sequence.
     
     - Note: If `object` can't be retained, none of the other closures will be invoked.
     
     - parameter object: The object to provide an unretained reference on.
     - parameter onSuccess: Action to invoke for each element in the observable sequence.
     - parameter onFailure: Action to invoke upon errored termination of the observable sequence.
     - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
     gracefully completed, errored, or if the generation is canceled by disposing subscription).
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    public func subscribe<Object: AnyObject>(
        with object: Object,
        onSuccess: ((Object, Element) -> Void)? = nil,
        onFailure: ((Object, Swift.Error) -> Void)? = nil,
        onDisposed: ((Object) -> Void)? = nil
    ) -> Disposable {
        subscribe(
            onSuccess: { [weak object] in
                guard let object = object else { return }
                onSuccess?(object, $0)
            },
            onFailure: { [weak object] in
                guard let object = object else { return }
                onFailure?(object, $0)
            },
            onDisposed: { [weak object] in
                guard let object = object else { return }
                onDisposed?(object)
            }
        )
    }
    
    /**
     Subscribes a success handler, and an error handler for this sequence.
     
     - parameter onSuccess: Action to invoke for each element in the observable sequence.
     - parameter onFailure: Action to invoke upon errored termination of the observable sequence.
     - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
     gracefully completed, errored, or if the generation is canceled by disposing subscription).
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    public func subscribe(onSuccess: ((Element) -> Void)? = nil,
                          onFailure: ((Swift.Error) -> Void)? = nil,
                          onDisposed: (() -> Void)? = nil) -> Disposable {
#if DEBUG
        let callStack = Hooks.recordCallStackOnError ? Thread.callStackSymbols : []
#else
        let callStack = [String]()
#endif
        
        let disposable: Disposable
        if let onDisposed = onDisposed {
            disposable = Disposables.create(with: onDisposed)
        } else {
            disposable = Disposables.create()
        }
        
        let observer: SingleObserver = { event in
            switch event {
            case .success(let element):
                onSuccess?(element)
                disposable.dispose()
            case .failure(let error):
                if let onFailure = onFailure {
                    onFailure(error)
                } else {
                    Hooks.defaultErrorHandler(callStack, error)
                }
                disposable.dispose()
            }
        }
        
        return Disposables.create(
            self.primitiveSequence.subscribe(observer),
            disposable
        )
    }
}

extension PrimitiveSequenceType where Trait == SingleTrait {
    /**
     Returns an observable sequence that contains a single element.
     
     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)
     
     - parameter element: Single element in the resulting observable sequence.
     - returns: An observable sequence containing the single specified element.
     */
    public static func just(_ element: Element) -> Single<Element> {
        Single(raw: Observable.just(element))
    }
    
    /**
     Returns an observable sequence that contains a single element.
     
     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)
     
     - parameter element: Single element in the resulting observable sequence.
     - parameter scheduler: Scheduler to send the single element on.
     - returns: An observable sequence containing the single specified element.
     */
    public static func just(_ element: Element, scheduler: ImmediateSchedulerType) -> Single<Element> {
        Single(raw: Observable.just(element, scheduler: scheduler))
    }
    
    /**
     Returns an observable sequence that terminates with an `error`.
     
     - seealso: [throw operator on reactivex.io](http://reactivex.io/documentation/operators/empty-never-throw.html)
     
     - returns: The observable sequence that terminates with specified error.
     */
    public static func error(_ error: Swift.Error) -> Single<Element> {
        PrimitiveSequence(raw: Observable.error(error))
    }
    
    /**
     Returns a non-terminating observable sequence, which can be used to denote an infinite duration.
     
     - seealso: [never operator on reactivex.io](http://reactivex.io/documentation/operators/empty-never-throw.html)
     
     - returns: An observable sequence whose observers will never get called.
     */
    public static func never() -> Single<Element> {
        PrimitiveSequence(raw: Observable.never())
    }
}

extension PrimitiveSequenceType where Trait == SingleTrait {
    
    /**
     Invokes an action for each event in the observable sequence, and propagates all observer messages through the result sequence.
     
     - seealso: [do operator on reactivex.io](http://reactivex.io/documentation/operators/do.html)
     
     - parameter onSuccess: Action to invoke for each element in the observable sequence.
     - parameter afterSuccess: Action to invoke for each element after the observable has passed an onNext event along to its downstream.
     - parameter onError: Action to invoke upon errored termination of the observable sequence.
     - parameter afterError: Action to invoke after errored termination of the observable sequence.
     - parameter onSubscribe: Action to invoke before subscribing to source observable sequence.
     - parameter onSubscribed: Action to invoke after subscribing to source observable sequence.
     - parameter onDispose: Action to invoke after subscription to source observable has been disposed for any reason. It can be either because sequence terminates for some reason or observer subscription being disposed.
     - returns: The source sequence with the side-effecting behavior applied.
     */
    public func `do`(onSuccess: ((Element) throws -> Void)? = nil,
                     afterSuccess: ((Element) throws -> Void)? = nil,
                     onError: ((Swift.Error) throws -> Void)? = nil,
                     afterError: ((Swift.Error) throws -> Void)? = nil,
                     onSubscribe: (() -> Void)? = nil,
                     onSubscribed: (() -> Void)? = nil,
                     onDispose: (() -> Void)? = nil)
    -> Single<Element> {
        return Single(raw: self.primitiveSequence.source.do(
            onNext: onSuccess,
            afterNext: afterSuccess,
            onError: onError,
            afterError: afterError,
            onSubscribe: onSubscribe,
            onSubscribed: onSubscribed,
            onDispose: onDispose)
        )
    }
    
    /**
     Filters the elements of an observable sequence based on a predicate.
     
     - seealso: [filter operator on reactivex.io](http://reactivex.io/documentation/operators/filter.html)
     
     - parameter predicate: A function to test each source element for a condition.
     - returns: An observable sequence that contains elements from the input sequence that satisfy the condition.
     */
    public func filter(_ predicate: @escaping (Element) throws -> Bool)
    -> Maybe<Element> {
        return Maybe(raw: self.primitiveSequence.source.filter(predicate))
    }
    
    /**
     Projects each element of an observable sequence into a new form.
     
     - seealso: [map operator on reactivex.io](http://reactivex.io/documentation/operators/map.html)
     
     - parameter transform: A transform function to apply to each source element.
     - returns: An observable sequence whose elements are the result of invoking the transform function on each element of source.
     
     */
    public func map<Result>(_ transform: @escaping (Element) throws -> Result)
    -> Single<Result> {
        return Single(raw: self.primitiveSequence.source.map(transform))
    }
    
    /**
     Projects each element of an observable sequence into an optional form and filters all optional results.
     
     - parameter transform: A transform function to apply to each source element.
     - returns: An observable sequence whose elements are the result of filtering the transform function for each element of the source.
     
     */
    public func compactMap<Result>(_ transform: @escaping (Element) throws -> Result?)
    -> Maybe<Result> {
        Maybe(raw: self.primitiveSequence.source.compactMap(transform))
    }
    
    /**
     Projects each element of an observable sequence to an observable sequence and merges the resulting observable sequences into one observable sequence.
     
     - seealso: [flatMap operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)
     
     - parameter selector: A transform function to apply to each element.
     - returns: An observable sequence whose elements are the result of invoking the one-to-many transform function on each element of the input sequence.
     */
    public func flatMap<Result>(_ selector: @escaping (Element) throws -> Single<Result>)
    -> Single<Result> {
        return Single<Result>(raw: self.primitiveSequence.source.flatMap(selector))
    }
    
    /**
     Projects each element of an observable sequence to an observable sequence and merges the resulting observable sequences into one observable sequence.
     
     - seealso: [flatMap operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)
     
     - parameter selector: A transform function to apply to each element.
     - returns: An observable sequence whose elements are the result of invoking the one-to-many transform function on each element of the input sequence.
     */
    public func flatMapMaybe<Result>(_ selector: @escaping (Element) throws -> Maybe<Result>)
    -> Maybe<Result> {
        return Maybe<Result>(raw: self.primitiveSequence.source.flatMap(selector))
    }
    
    /**
     Projects each element of an observable sequence to an observable sequence and merges the resulting observable sequences into one observable sequence.
     
     - seealso: [flatMap operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)
     
     - parameter selector: A transform function to apply to each element.
     - returns: An observable sequence whose elements are the result of invoking the one-to-many transform function on each element of the input sequence.
     */
    public func flatMapCompletable(_ selector: @escaping (Element) throws -> Completable)
    -> Completable {
        return Completable(raw: self.primitiveSequence.source.flatMap(selector))
    }
    
    /**
     Merges the specified observable sequences into one observable sequence by using the selector function whenever all of the observable sequences have produced an element at a corresponding index.
     
     - parameter resultSelector: Function to invoke for each series of elements at corresponding indexes in the sources.
     - returns: An observable sequence containing the result of combining elements of the sources using the specified result selector function.
     */
    public static func zip<Collection: Swift.Collection, Result>(_ collection: Collection, resultSelector: @escaping ([Element]) throws -> Result) -> PrimitiveSequence<Trait, Result> where Collection.Element == PrimitiveSequence<Trait, Element> {
        
        if collection.isEmpty {
            return PrimitiveSequence<Trait, Result>.deferred {
                return PrimitiveSequence<Trait, Result>(raw: .just(try resultSelector([])))
            }
        }
        
        let raw = Observable.zip(collection.map { $0.asObservable() }, resultSelector: resultSelector)
        return PrimitiveSequence<Trait, Result>(raw: raw)
    }
    
    /**
     Merges the specified observable sequences into one observable sequence all of the observable sequences have produced an element at a corresponding index.
     
     - returns: An observable sequence containing the result of combining elements of the sources.
     */
    public static func zip<Collection: Swift.Collection>(_ collection: Collection) -> PrimitiveSequence<Trait, [Element]> where Collection.Element == PrimitiveSequence<Trait, Element> {
        
        if collection.isEmpty {
            return PrimitiveSequence<Trait, [Element]>(raw: .just([]))
        }
        
        let raw = Observable.zip(collection.map { $0.asObservable() })
        return PrimitiveSequence(raw: raw)
    }
    
    /**
     Continues an observable sequence that is terminated by an error with a single element.
     
     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)
     
     - parameter element: Last element in an observable sequence in case error occurs.
     - returns: An observable sequence containing the source sequence's elements, followed by the `element` in case an error occurred.
     */
    public func catchAndReturn(_ element: Element)
    -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence(raw: self.primitiveSequence.source.catchAndReturn(element))
    }
    
    /// Converts `self` to `Maybe` trait.
    ///
    /// - returns: Maybe trait that represents `self`.
    public func asMaybe() -> Maybe<Element> {
        Maybe(raw: self.primitiveSequence.source)
    }
    
    /// Converts `self` to `Completable` trait, ignoring its emitted value if
    /// one exists.
    ///
    /// - returns: Completable trait that represents `self`.
    public func asCompletable() -> Completable {
        self.primitiveSequence.source.ignoreElements().asCompletable()
    }
}
