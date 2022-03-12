//
//  ControlEvent.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 8/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift

/*
 对于 ControlEventType 的定义, 一定是先有 ControlEvent, 才有 ControlEventType 的定义.
 更多的接口, 使用的是 ControlEventType 的抽象. 这样, 可以传递各种数据类型进入, 只要这个数据类型, 能够满足 asControlEvent 的定义就好了.
 在 Swift 这种可以添加 Extension 的机制下, 这是一种, 更加灵活的方式.
 */
public protocol ControlEventType : ObservableType {
    
    /// - returns: `ControlEvent` interface
    func asControlEvent() -> ControlEvent<Element>
}

/*
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

// 先是有 ControlEvent, 然后有 ControlEventType
// 而 ControlEvent 对于 ControlEventType 的实现, 就是返回自己本身
// 这是一个非常通用的设计.
public struct ControlEvent<PropertyType> : ControlEventType {
    
    public typealias Element = PropertyType
    
    let events: Observable<PropertyType> // 传递一个 Publsiher 过来, 进行了在主线程调度的变化, 真正使用的是这个会在主线程传递数据给后续节点的 Event Publisher.
    
    /// Initializes control event with a observable sequence that represents events.
    ///
    /// - parameter events: Observable sequence that represents events.
    /// - returns: Control event created with a observable sequence of events.
    // ControlEvent 并不管理 events 的构建过程, 这个过程是外部创建的.
    public init<Ev: ObservableType>(events: Ev) where Ev.Element == Element {
        self.events = events.subscribe(on: ConcurrentMainScheduler.instance)
    }
    
    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.events.subscribe(observer)
    }
    
    /*
     各种 as 表示的是, 能够提供对应结构的对象. 至于是 self, 还是自己的属性, 还是自己新构建的, 其实不是太重要.
     */
    public func asObservable() -> Observable<Element> {
        self.events
    }
    
    public func asControlEvent() -> ControlEvent<Element> {
        self
    }
}
