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
 - it `Complete`s the sequence when the control deallocates, 当, Control 消亡的时候, 发射 Complete 信号.
 - it never errors out // 用户操作不可能有错
 - it delivers events on `MainScheduler.instance`. // UI 操作 .
 
 // 在主线程进行注册.
 **The implementation of `ControlEvent` will ensure that sequence of events is being subscribed on main scheduler
 (`subscribe(on: ConcurrentMainScheduler.instance)` behavior).**
 
 **It is the implementor’s responsibility to make sure that all other properties enumerated above are satisfied.**
 
 **If they aren’t, using this trait will communicate wrong properties, and could potentially break someone’s code.**
 
 **If the `events` observable sequence passed into the initializer doesn’t satisfy all enumerated
 properties, don’t use this trait.**
 */

// 无论是 ControlProperty, 还是 ControlEvent, 都没有将信号的创建, 包装到自己的内部.
// 而是在外界进行创建, 然后自己仅仅是作为概念的包装.


/*
 核心, 还是 Obsersables, 但是有了很多的对于 obsersable 的包装类.
 这些包装类, 都提供了变化成为 obsersable 的接口, 这些包装类里面的类型参数, 也都和 Observable 的一致.
 
 这些包装类的主要作用, 1. 在 init 的时候, 最传入的 obsersable 进行加工, 所以这些包装类里面, 存储的已经不是传入的最原始的信号了, 而是自己加工后的.
 2. 增加独特的接口, 使得外界使用的时候, 更加的方便.
 */
public struct ControlEvent<PropertyType> : ControlEventType {
    
    public typealias Element = PropertyType
    
    // ControlEvent 包装了外部的一个 Publisher. 在主线程进行 subscribe. 
    let events: Observable<PropertyType>
    
    /// Initializes control event with a observable sequence that represents events.
    ///
    /// - parameter events: Observable sequence that represents events.
    /// - returns: Control event created with a observable sequence of events.
    
    // ControlEvent 并不管理 events 的构建过程, 这个过程是外部创建的.
    
    public init<Ev: ObservableType>(events: Ev) where Ev.Element == Element {
        // 确保了, 在主线程进行注册操作. 
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
