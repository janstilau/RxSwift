//
//  PrimitiveSequence.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/5/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

/*
 PrimitiveSequence 并不是一个 Publisher, 他是一个包含了 Publisher 的类型.
 他想要完成, Pusblisher 的操作, 还是要将各个后续节点, 连接到包含的 source 上才可以.
 
 他的存在, 主要是为了完成某些特殊的操作. 当 Trait 不同的时候, 可以有不同的特殊的 API 执行. 这就是这个类存在的主要的意义.
 Sigle, MayBe, Completeable, 可以调用 subscribe 来触发各自版本的监听函数, 其实这些监听函数, 还是要转换为监听 event, 只不过这个过程, 被封装到了 PrimitiveSequence 的内部.
 
 PrimitiveSequence 是将这些操作, 都包装到了自己的接口上, 所以 asSingle, asMaybe, 各种操作, 需要返回的是 PrimitiveSequence 对象.
 */

// 这里, 其实已经讲的很清楚了. Source 
// Observable sequences containing 0 or 1 element.
// 这里说的很清楚, 使用 PrimitiveSequence 最多只应该有一个 Next 事件.
public struct PrimitiveSequence<Trait, Element> {
    let source: Observable<Element>
    // Element 是为了确定事件的关联数据类型.
    // Trait 就是为了编译分化的.
    init(raw: Observable<Element>) {
        self.source = raw
    }
}

/// Observable sequences containing 0 or 1 element
// 各种都是在 Protocol 上, 增加方法. 这样所有的实现类, 都可以直接使用.
// Protocol Extension 应该使用 Protocol 中的 Primitive Method 进行编程.
// 这里, Primitive Method 其实就是 init 方法. 所以各个 Extension 里面的方法, 就是操作 source, 然后使用新创建的 Source 进行 init.
public protocol PrimitiveSequenceType {
    /// Additional constraints
    // 这个类型, 没有真正的参与到类的使用里面, 它仅仅是在编译的时候, 做类型区分的.
    // public typealias Single<Element> = PrimitiveSequence<SingleTrait, Element>
    // Single 的 Trait, 是 SingleTrait 这个类型, 在这个类型下, 为 PrimitiveSequenceType 增加了很多的方法. 这些方法只能在 Single 下使用.
    // 这是编译控制的.
    associatedtype Trait
    
    /// Sequence element type
    associatedtype Element
    
    // Converts `self` to primitive sequence.
    ///
    /// - returns: Observable sequence that represents `self`.
    var primitiveSequence: PrimitiveSequence<Trait, Element> { get }
}

extension PrimitiveSequence: PrimitiveSequenceType {
    // Converts `self` to primitive sequence.
    ///
    /// - returns: Observable sequence that represents `self`.
    public var primitiveSequence: PrimitiveSequence<Trait, Element> {
        self
    }
}

// PrimitiveSequence 并不是一个 Observable, 他仅仅是 ObservableConvertibleType
// 所以, 如果想要当做一个 Observable 来使用, 先要使用 asObservable 获取一个 Observable 对象.
// 如果直接使用 PrimitiveSequence, 主要是为了使用它的 Trait 方法.

// 这里可以看到, ObservableConvertibleType 和 ObservableType 的区别了.
// ObservableType 能够直接进行 subscribe, 而 ObservableConvertibleType 需要专门调用 asObservable 来获取到 ObservableType, 然后才能进行 subscribe
// ObservableConvertibleType 在这里被用到了, 他并不是一个 ObservableType, 但是可以使用 asObservable 纳入到响应式的世界里面.
// 给他添加各种方法, 并不是在 ObservableType 上添加, 而是给这个特殊类型上增加, 增加的都是特化方法.
// 然后这些特化方法, 还是要纳入到响应式的世界里面, 就调用 asObservable, 来获取到原本的 Observable, 使用原本的概念, 来实现这些特化方法.
extension PrimitiveSequence: ObservableConvertibleType {
    public func asObservable() -> Observable<Element> {
        self.source
    }
}

extension PrimitiveSequence {
    /*
     Returns an observable sequence that invokes the specified factory function whenever a new observer subscribes.
     */
    public static func deferred(_ observableFactory: @escaping () throws -> PrimitiveSequence<Trait, Element>)
    -> PrimitiveSequence<Trait, Element> {
        return PrimitiveSequence(raw: Observable.deferred {
            try observableFactory().asObservable()
        })
    }
    
    /**
     Returns an observable sequence by the source observable sequence shifted forward in time by a specified delay. Error events from the source observable sequence are not delayed.
     
     - seealso: [delay operator on reactivex.io](http://reactivex.io/documentation/operators/delay.html)
     
     - parameter dueTime: Relative time shift of the source by.
     - parameter scheduler: Scheduler to run the subscription delay timer on.
     - returns: the source Observable shifted in time by the specified delay.
     */
    public func delay(_ dueTime: RxTimeInterval, scheduler: SchedulerType)
    -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence(raw: self.primitiveSequence.source.delay(dueTime, scheduler: scheduler))
    }
    
    /**
     Time shifts the observable sequence by delaying the subscription with the specified relative time duration, using the specified scheduler to run timers.
     
     - seealso: [delay operator on reactivex.io](http://reactivex.io/documentation/operators/delay.html)
     
     - parameter dueTime: Relative time shift of the subscription.
     - parameter scheduler: Scheduler to run the subscription delay timer on.
     - returns: Time-shifted sequence.
     */
    public func delaySubscription(_ dueTime: RxTimeInterval, scheduler: SchedulerType)
    -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence(raw: self.source.delaySubscription(dueTime, scheduler: scheduler))
    }
    
    /**
     Wraps the source sequence in order to run its observer callbacks on the specified scheduler.
     
     This only invokes observer callbacks on a `scheduler`. In case the subscription and/or unsubscription
     actions have side-effects that require to be run on a scheduler, use `subscribeOn`.
     
     - seealso: [observeOn operator on reactivex.io](http://reactivex.io/documentation/operators/observeon.html)
     
     - parameter scheduler: Scheduler to notify observers on.
     - returns: The source sequence whose observations happen on the specified scheduler.
     */
    public func observe(on scheduler: ImmediateSchedulerType)
    -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence(raw: self.source.observe(on: scheduler))
    }
    
    /**
     Wraps the source sequence in order to run its subscription and unsubscription logic on the specified
     scheduler.
     
     This operation is not commonly used.
     
     This only performs the side-effects of subscription and unsubscription on the specified scheduler.
     
     In order to invoke observer callbacks on a `scheduler`, use `observeOn`.
     
     - seealso: [subscribeOn operator on reactivex.io](http://reactivex.io/documentation/operators/subscribeon.html)
     
     - parameter scheduler: Scheduler to perform subscription and unsubscription actions on.
     - returns: The source sequence whose subscriptions and unsubscriptions happen on the specified scheduler.
     */
    public func subscribe(on scheduler: ImmediateSchedulerType)
    -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence(raw: self.source.subscribe(on: scheduler))
    }
    
    /**
     Continues an observable sequence that is terminated by an error with the observable sequence produced by the handler.
     
     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)
     
     - parameter handler: Error handler function, producing another observable sequence.
     - returns: An observable sequence containing the source sequence's elements, followed by the elements produced by the handler's resulting observable sequence in case an error occurred.
     */
    public func `catch`(_ handler: @escaping (Swift.Error) throws -> PrimitiveSequence<Trait, Element>)
    -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence(raw: self.source.catch { try handler($0).asObservable() })
    }
    
    /**
     If the initial subscription to the observable sequence emits an error event, try repeating it up to the specified number of attempts (inclusive of the initial attempt) or until is succeeds. For example, if you want to retry a sequence once upon failure, you should use retry(2) (once for the initial attempt, and once for the retry).
     
     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)
     
     - parameter maxAttemptCount: Maximum number of times to attempt the sequence subscription.
     - returns: An observable sequence producing the elements of the given sequence repeatedly until it terminates successfully.
     */
    public func retry(_ maxAttemptCount: Int)
    -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence(raw: self.source.retry(maxAttemptCount))
    }
    
    /**
     Repeats the source observable sequence on error when the notifier emits a next value.
     If the source observable errors and the notifier completes, it will complete the source sequence.
     
     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)
     
     - parameter notificationHandler: A handler that is passed an observable sequence of errors raised by the source observable and returns and observable that either continues, completes or errors. This behavior is then applied to the source observable.
     - returns: An observable sequence producing the elements of the given sequence repeatedly until it terminates successfully or is notified to error or complete.
     */
    public func retry<TriggerObservable: ObservableType, Error: Swift.Error>(when notificationHandler: @escaping (Observable<Error>) -> TriggerObservable)
    -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence(raw: self.source.retry(when: notificationHandler))
    }
    
    /**
     Repeats the source observable sequence on error when the notifier emits a next value.
     If the source observable errors and the notifier completes, it will complete the source sequence.
     
     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)
     
     - parameter notificationHandler: A handler that is passed an observable sequence of errors raised by the source observable and returns and observable that either continues, completes or errors. This behavior is then applied to the source observable.
     - returns: An observable sequence producing the elements of the given sequence repeatedly until it terminates successfully or is notified to error or complete.
     */
    public func retry<TriggerObservable: ObservableType>(when notificationHandler: @escaping (Observable<Swift.Error>) -> TriggerObservable)
    -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence(raw: self.source.retry(when: notificationHandler))
    }
    
    /**
     Prints received events for all observers on standard output.
     
     - seealso: [do operator on reactivex.io](http://reactivex.io/documentation/operators/do.html)
     
     - parameter identifier: Identifier that is printed together with event description to standard output.
     - parameter trimOutput: Should output be trimmed to max 40 characters.
     - returns: An observable sequence whose events are printed to standard output.
     */
    public func debug(_ identifier: String? = nil, trimOutput: Bool = false, file: String = #file, line: UInt = #line, function: String = #function)
    -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence(raw: self.source.debug(identifier, trimOutput: trimOutput, file: file, line: line, function: function))
    }
    
    /**
     Constructs an observable sequence that depends on a resource object, whose lifetime is tied to the resulting observable sequence's lifetime.
     
     - seealso: [using operator on reactivex.io](http://reactivex.io/documentation/operators/using.html)
     
     - parameter resourceFactory: Factory function to obtain a resource object.
     - parameter primitiveSequenceFactory: Factory function to obtain an observable sequence that depends on the obtained resource.
     - returns: An observable sequence whose lifetime controls the lifetime of the dependent resource object.
     */
    public static func using<Resource: Disposable>(_ resourceFactory: @escaping () throws -> Resource, primitiveSequenceFactory: @escaping (Resource) throws -> PrimitiveSequence<Trait, Element>)
    -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence(raw: Observable.using(resourceFactory, observableFactory: { (resource: Resource) throws -> Observable<Element> in
            return try primitiveSequenceFactory(resource).asObservable()
        }))
    }
    
    /**
     Applies a timeout policy for each element in the observable sequence. If the next element isn't received within the specified timeout duration starting from its predecessor, a TimeoutError is propagated to the observer.
     
     - seealso: [timeout operator on reactivex.io](http://reactivex.io/documentation/operators/timeout.html)
     
     - parameter dueTime: Maximum duration between values before a timeout occurs.
     - parameter scheduler: Scheduler to run the timeout timer on.
     - returns: An observable sequence with a `RxError.timeout` in case of a timeout.
     */
    public func timeout(_ dueTime: RxTimeInterval, scheduler: SchedulerType)
    -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence<Trait, Element>(raw: self.primitiveSequence.source.timeout(dueTime, scheduler: scheduler))
    }
    
    /**
     Applies a timeout policy for each element in the observable sequence, using the specified scheduler to run timeout timers. If the next element isn't received within the specified timeout duration starting from its predecessor, the other observable sequence is used to produce future messages from that point on.
     
     - seealso: [timeout operator on reactivex.io](http://reactivex.io/documentation/operators/timeout.html)
     
     - parameter dueTime: Maximum duration between values before a timeout occurs.
     - parameter other: Sequence to return in case of a timeout.
     - parameter scheduler: Scheduler to run the timeout timer on.
     - returns: The source sequence switching to the other sequence in case of a timeout.
     */
    public func timeout(_ dueTime: RxTimeInterval,
                        other: PrimitiveSequence<Trait, Element>,
                        scheduler: SchedulerType) -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence<Trait, Element>(raw: self.primitiveSequence.source.timeout(dueTime, other: other.source, scheduler: scheduler))
    }
}

extension PrimitiveSequenceType where Element: RxAbstractInteger
{
    /**
     Returns an observable sequence that periodically produces a value after the specified initial relative due time has elapsed, using the specified scheduler to run timers.
     
     - seealso: [timer operator on reactivex.io](http://reactivex.io/documentation/operators/timer.html)
     
     - parameter dueTime: Relative time at which to produce the first value.
     - parameter scheduler: Scheduler to run timers on.
     - returns: An observable sequence that produces a value after due time has elapsed and then each period.
     */
    public static func timer(_ dueTime: RxTimeInterval, scheduler: SchedulerType)
    -> PrimitiveSequence<Trait, Element>  {
        PrimitiveSequence(raw: Observable<Element>.timer(dueTime, scheduler: scheduler))
    }
}
