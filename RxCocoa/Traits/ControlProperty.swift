//
//  ControlProperty.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 8/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift

/*
 又能当做 Publisher, 又能当做 Observer
 */
public protocol ControlPropertyType : ObservableType, ObserverType {
    func asControlProperty() -> ControlProperty<Element>
}

/*
 Trait for `Observable`/`ObservableType` that represents property of UI element.
 
 // 只会对 UI 初始值, 以及用户触发的改变发出信号. 这其实是 target action 的机制导致的.
 Sequence of values only represents initial control value and user initiated value changes.
 Programmatic value changes won't be reported.
 
 It's properties are:
 
 - `shareReplay(1)` behavior
 - it's stateful, upon subscription (calling subscribe) last element is immediately replayed if it was produced
 // 最后会有一个 completion, 所以当 UI 消亡的时候, 可以通知使用了 UI 的 Publisher 的地方
 - it will `Complete` sequence on control being deallocated
 // UI 事件的通用设计.
 - it never errors out
 - it delivers events on `MainScheduler.instance`
 
 **The implementation of `ControlProperty` will ensure that sequence of values is being subscribed on main scheduler
 (`subscribe(on: ConcurrentMainScheduler.instance)` behavior).**
 
 **It is implementor's responsibility to make sure that that all other properties enumerated above are satisfied.**
 
 **If they aren't, then using this trait communicates wrong properties and could potentially break someone's code.**
 
 **In case `values` observable sequence that is being passed into initializer doesn't satisfy all enumerated
 properties, please don't use this trait.**
 */

/*
 能够当做 Publisher, 是因为在内部, 进行了 target action 的监听, 当改变自身值的时候, 进行了信号的发射.
 能够当做 Observer, 因为有一个 binder, 当外界信号发出的时候, 在 Binder 内部, 对所控制的 UI 进行了修改.
 但是这都是外界传递过来的.
 */
public struct ControlProperty<PropertyType> : ControlPropertyType {
    
    public typealias Element = PropertyType
    
    // ControlProperty 中, values 其实保证了, 一定是 Event 才会触发信号的发送. 
    let values: Observable<PropertyType> // Publisher. 
    let valueSink: AnyObserver<PropertyType> // Binder
    
    /// Initializes control property with a observable sequence that represents property values and observer that enables
    /// binding values to property.
    public init<Values: ObservableType, Sink: ObserverType>(values: Values,
                                                            valueSink: Sink) where Element == Values.Element, Element == Sink.Element {
        self.values = values.subscribe(on: ConcurrentMainScheduler.instance)
        self.valueSink = valueSink.asObserver()
    }
    
    /// Subscribes an observer to control property values.
    ///
    /// - parameter observer: Observer to subscribe to property values.
    /// - returns: Disposable object that can be used to unsubscribe the observer from receiving control property values.
    // 充当发布者的角色, 就是使用自己的 Publisher 序列.
    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.values.subscribe(observer)
    }
    
    /// `ControlEvent` of user initiated value changes. Every time user updates control value change event
    /// will be emitted from `changed` event.
    ///
    /// Programmatic changes to control value won't be reported.
    ///
    /// It contains all control property values except for first one.
    ///
    /// The name only implies that sequence element will be generated once user changes a value and not that
    /// adjacent sequence values need to be different (e.g. because of interaction between programmatic and user updates,
    /// or for any other reason).
    public var changed: ControlEvent<PropertyType> {
        // self.values 是
        ControlEvent(events: self.values.skip(1))
    }
    
    /// - returns: `Observable` interface.
    public func asObservable() -> Observable<Element> {
        self.values
    }
    
    /// - returns: `ControlProperty` interface.
    public func asControlProperty() -> ControlProperty<Element> {
        self
    }
    
    /// Binds event to user interface.
    ///
    /// - In case next element is received, it is being set to control value.
    /// - In case error is received, DEBUG builds raise fatal error, RELEASE builds log event to standard output.
    /// - In case sequence completes, nothing happens.
    
    /*
     对于 Control 的 PropertyObserver 来说, 它的作用就是, 在将数据传递给自己的 valueSink
     */
    public func on(_ event: Event<Element>) {
        switch event {
        case .error(let error):
            bindingError(error)
        case .next:
            self.valueSink.on(event)
        case .completed:
            self.valueSink.on(event)
        }
    }
}

extension ControlPropertyType where Element == String? {
    /*
     对于原有的 ControlProperty 的包装, 其实就是修改了一下, Pusblisher 的输出值. 
     */
    public var orEmpty: ControlProperty<String> {
        let original: ControlProperty<String?> = self.asControlProperty()
        // 如果, 原有序列是 nil, 直接这里转化一次, 变为 ""
        let values: Observable<String> = original.values.map { $0 ?? "" }
        
        // 这里不是太明白. original.valueSink.mapObserver { $0 } 是 String? 类型的, 怎么变为 String 类型的了
        let valueSink: AnyObserver<String> = original.valueSink.mapObserver { $0 }
        return ControlProperty<String>(values: values, valueSink: valueSink)
    }
}
