//
//  SharedSequence.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 8/27/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift

/*
 Trait that represents observable sequence that shares computation resources with following properties:
 
 - it never fails
 - it delivers events on `SharingStrategy.scheduler`
 - sharing strategy is customizable using `SharingStrategy.share` behavior
 
 `SharedSequence<Element>` can be considered a builder pattern for observable sequences that share computation resources.
 
 To find out more about units and how to use them, please visit `Documentation/Traits.md`.
 */

/*
 这是一个构建器. 很像是 C++ 的写法.
 这个构建器, 使用一个 SharingStrategyProtocol 来做调度, 将传入的 Publisher, 变为一个 sharedPublisher.
 而具体的 SharingStrategyProtocol 应该是什么, 不是动态传入的, 而已编写过程中, 有 SharingStrategyProtocol 的开发人员指定的.
 
 一般来说, 将类型参数, 真正的当参数来使用, 一般是静态方法偏多.
 不过也不是绝对的, 使用类型参数, 构建一个对象, 然后调用对象方法来完成静态方法的工作也没有什么问题.
 */

// public typealias Driver<Element> = SharedSequence<DriverSharingStrategy, Element>
// public typealias Signal<Element> = SharedSequence<SignalSharingStrategy, Element>

// SharingStrategy 到底是什么, 不重要, 重要的是可以使用 SharingStrategy.share 将一个 source, 变为了 sharedSource.
public struct SharedSequence<SharingStrategy: SharingStrategyProtocol, Element> :
    SharedSequenceConvertibleType, ObservableConvertibleType {
    
    let source: Observable<Element>
    
    // 最重要的抽象, 其实就是对 source 进行了一次 share 处理.
    // share 是一个常见的事情, 所以将这些包装起来.
    // 只要使用了 SharedSequence, 一定会触发 share. 这要比依靠外界使用者, 主动调用 share 靠谱的多. 
    init(_ source: Observable<Element>) {
        self.source = SharingStrategy.share(source)
    }
    
    init(raw: Observable<Element>) {
        self.source = raw
    }
    
    /**
     - returns: Built observable sequence.
     */
    public func asObservable() -> Observable<Element> {
        self.source
    }
    
    /**
     - returns: `self`
     */
    public func asSharedSequence() -> SharedSequence<SharingStrategy, Element> {
        self
    }
}

/*
 Different `SharedSequence` sharing strategies must conform to this protocol.
 
 这个协议, 主要提供两个功能, 调度器, 以及如何把一个 Publisher 变为 shared Publihser.
 */
public protocol SharingStrategyProtocol {
    /**
     Scheduled on which all sequence events will be delivered.
     */
    static var scheduler: SchedulerType { get }
    
    /**
     Computation resources sharing strategy for multiple sequence observers.
     
     E.g. One can choose `share(replay:scope:)`
     as sequence event sharing strategies, but also do something more exotic, like
     implementing promises or lazy loading chains.
     */
    static func share<Element>(_ source: Observable<Element>) -> Observable<Element>
}

/*
 
 public struct DriverSharingStrategy: SharingStrategyProtocol {
     
     public static var scheduler: SchedulerType { SharingScheduler.make() }
     
     public static func share<Element>(_ source: Observable<Element>) -> Observable<Element> {
         source.share(replay: 1, scope: .whileConnected)
     }
 }
 
 public struct SignalSharingStrategy: SharingStrategyProtocol {
     
     public static var scheduler: SchedulerType { SharingScheduler.make() }
     
     public static func share<Element>(_ source: Observable<Element>) -> Observable<Element> {
         source.share(scope: .whileConnected)
     }
 }
 
 大部分的能力, 还是 ObservableConvertibleType 上添加的. 但是在
 
 DriverSharingStrategy, SignalSharingStrategy 下, 可以有着更加特化的方法可以调用.
 */

/*
 A type that can be converted to `SharedSequence`.
 */
public protocol SharedSequenceConvertibleType : ObservableConvertibleType {
    associatedtype SharingStrategy: SharingStrategyProtocol
    /**
     Converts self to `SharedSequence`.
     */
    func asSharedSequence() -> SharedSequence<SharingStrategy, Element>
}

extension SharedSequenceConvertibleType {
    public func asObservable() -> Observable<Element> {
        self.asSharedSequence().asObservable()
    }
}


// 以下的所有方法, 都是在做一件事事情,
// 使用 SharingStrategy 的调度器, 进行调度, 然后构造函数里面, 使用 SharingStrategy 的 share 方法, 把原有的 Publisher 共享;
extension SharedSequence {
    
    /*
     init(raw: Observable<Element>)  在这里被用到了.
     当, 传入的 Source 不需要共享的时候, 可以省略共享节点这一层逻辑.
     */
    /*
     Returns an empty observable sequence, using the specified scheduler to send out the single `Completed` message.
     */
    public static func empty() -> SharedSequence<SharingStrategy, Element> {
        SharedSequence(raw: Observable.empty().subscribe(on: SharingStrategy.scheduler))
    }
    
    /*
     Returns a non-terminating observable sequence, which can be used to denote an infinite duration.
     */
    public static func never() -> SharedSequence<SharingStrategy, Element> {
        SharedSequence(raw: Observable.never())
    }
    
    /*
     Returns an observable sequence that contains a single element.
     */
    public static func just(_ element: Element) -> SharedSequence<SharingStrategy, Element> {
        SharedSequence(raw: Observable.just(element).subscribe(on: SharingStrategy.scheduler))
    }
    
    /**
     Returns an observable sequence that invokes the specified factory function whenever a new observer subscribes.
     
     - parameter observableFactory: Observable factory function to invoke for each observer that subscribes to the resulting sequence.
     - returns: An observable sequence whose observers trigger an invocation of the given observable factory function.
     */
    public static func deferred(_ observableFactory: @escaping () -> SharedSequence<SharingStrategy, Element>)
    -> SharedSequence<SharingStrategy, Element> {
        SharedSequence(Observable.deferred { observableFactory().asObservable() })
    }
    
    /**
     This method creates a new Observable instance with a variable number of elements.
     
     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)
     
     - parameter elements: Elements to generate.
     - returns: The observable sequence whose elements are pulled from the given arguments.
     */
    public static func of(_ elements: Element ...) -> SharedSequence<SharingStrategy, Element> {
        let source = Observable.from(elements, scheduler: SharingStrategy.scheduler)
        return SharedSequence(raw: source)
    }
}

extension SharedSequence {
    
    /**
     This method converts an array to an observable sequence.
     
     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)
     
     - returns: The observable sequence whose elements are pulled from the given enumerable sequence.
     */
    public static func from(_ array: [Element]) -> SharedSequence<SharingStrategy, Element> {
        let source = Observable.from(array, scheduler: SharingStrategy.scheduler)
        return SharedSequence(raw: source)
    }
    
    /**
     This method converts a sequence to an observable sequence.
     
     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)
     
     - returns: The observable sequence whose elements are pulled from the given enumerable sequence.
     */
    public static func from<Sequence: Swift.Sequence>(_ sequence: Sequence) -> SharedSequence<SharingStrategy, Element> where Sequence.Element == Element {
        let source = Observable.from(sequence, scheduler: SharingStrategy.scheduler)
        return SharedSequence(raw: source)
    }
    
    /**
     This method converts a optional to an observable sequence.
     
     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)
     
     - parameter optional: Optional element in the resulting observable sequence.
     
     - returns: An observable sequence containing the wrapped value or not from given optional.
     */
    public static func from(optional: Element?) -> SharedSequence<SharingStrategy, Element> {
        let source = Observable.from(optional: optional, scheduler: SharingStrategy.scheduler)
        return SharedSequence(raw: source)
    }
}

extension SharedSequence where Element: RxAbstractInteger {
    /**
     Returns an observable sequence that produces a value after each period, using the specified scheduler to run timers and to send out observer messages.
     
     - seealso: [interval operator on reactivex.io](http://reactivex.io/documentation/operators/interval.html)
     
     - parameter period: Period for producing the values in the resulting sequence.
     - returns: An observable sequence that produces a value after each period.
     */
    public static func interval(_ period: RxTimeInterval)
    -> SharedSequence<SharingStrategy, Element> {
        SharedSequence(Observable.interval(period, scheduler: SharingStrategy.scheduler))
    }
}

// MARK: timer

extension SharedSequence where Element: RxAbstractInteger {
    /**
     Returns an observable sequence that periodically produces a value after the specified initial relative due time has elapsed, using the specified scheduler to run timers.
     
     - seealso: [timer operator on reactivex.io](http://reactivex.io/documentation/operators/timer.html)
     
     - parameter dueTime: Relative time at which to produce the first value.
     - parameter period: Period to produce subsequent values.
     - returns: An observable sequence that produces a value after due time has elapsed and then each period.
     */
    public static func timer(_ dueTime: RxTimeInterval, period: RxTimeInterval)
    -> SharedSequence<SharingStrategy, Element> {
        SharedSequence(Observable.timer(dueTime, period: period, scheduler: SharingStrategy.scheduler))
    }
}

