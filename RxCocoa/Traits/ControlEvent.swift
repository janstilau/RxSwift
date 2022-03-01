//
//  ControlEvent.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 8/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift

// ControlEvent 是用来充当 Publisher 的.
// 获取之后, 该 Control 在触发某个事件的时候, 就会发送信号.
public protocol ControlEventType : ObservableType {

    /// - returns: `ControlEvent` interface
    func asControlEvent() -> ControlEvent<Element>
}

/**
    A trait for `Observable`/`ObservableType` that represents an event on a UI element.

    Properties:

    - it doesn’t send any initial value on subscription, 没有初始信号, 因为都是事件, 需要用户主动调用.
    - it `Complete`s the sequence when the control deallocates,
    - it never errors out // 用户操作不可能有错
    - it delivers events on `MainScheduler.instance`. // UI 操作 .

    **The implementation of `ControlEvent` will ensure that sequence of events is being subscribed on main scheduler
     (`subscribe(on: ConcurrentMainScheduler.instance)` behavior).**

    **It is the implementor’s responsibility to make sure that all other properties enumerated above are satisfied.**

    **If they aren’t, using this trait will communicate wrong properties, and could potentially break someone’s code.**

    **If the `events` observable sequence passed into the initializer doesn’t satisfy all enumerated
     properties, don’t use this trait.**
*/
public struct ControlEvent<PropertyType> : ControlEventType {
    
    public typealias Element = PropertyType

    let events: Observable<PropertyType> // 传递一个 Publsiher 过来, 进行了在主线程调度的变化, 真正使用的是这个会在主线程传递数据给后续节点的 Event Publisher.

    /// Initializes control event with a observable sequence that represents events.
    ///
    /// - parameter events: Observable sequence that represents events.
    /// - returns: Control event created with a observable sequence of events.
    public init<Ev: ObservableType>(events: Ev) where Ev.Element == Element {
        self.events = events.subscribe(on: ConcurrentMainScheduler.instance)
    }

    /// Subscribes an observer to control events.
    ///
    /// - parameter observer: Observer to subscribe to events.
    /// - returns: Disposable object that can be used to unsubscribe the observer from receiving control events.
    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.events.subscribe(observer)
    }

    /*
        各种 as 表示的是, 能够提供对应结构的对象. 至于是 self, 还是自己的属性, 还是自己新构建的, 其实不是太重要.
     */
    /// - returns: `Observable` interface.
    public func asObservable() -> Observable<Element> {
        self.events
    }

    /// - returns: `ControlEvent` interface.
    public func asControlEvent() -> ControlEvent<Element> {
        self
    }
}
