//
//  AnyObserver.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// A type-erased `ObserverType`.
///
/// Forwards operations to an arbitrary underlying observer with the same `Element` type, hiding the specifics of the underlying observer type.

/*
 这种, Any 开头的类型, 一般就是在内存存储一个闭包, 然后在实现接口的时候, 使用这个闭包.
 可以直接指定这个闭包, 也可以使用一个对象方法传递这个闭包. 这种写法, 这个对象的生命周期会被保留.
 
 type-erased 的意义就在这里. 传入一个实现了 ObserverType 的特定的类型, 在 AnyObserver 存储它的方法实现, 同时保留生命周期.
 */

public struct AnyObserver<Element> : ObserverType {
    /// Anonymous event handler type.
    public typealias EventHandler = (Event<Element>) -> Void
    
    private let observer: EventHandler // 接口实现的 block 对象 .
    
    /// Construct an instance whose `on(event)` calls `eventHandler(event)`
    ///
    /// - parameter eventHandler: Event handler that observes sequences events.
    public init(eventHandler: @escaping EventHandler) {
        self.observer = eventHandler
    }
    
    /// Construct an instance whose `on(event)` calls `observer.on(event)`
    ///
    /// - parameter observer: Observer that receives sequence events.
    public init<Observer: ObserverType>(_ observer: Observer) where Observer.Element == Element {
        // 直接闭包的传递, 这种写法, 会进行 observer 的引用.
        self.observer = observer.on
    }
    
    /// Send `event` to this observer.
    ///
    /// - parameter event: Event instance.
    public func on(_ event: Event<Element>) {
        // 在实现接口的时候, 直接使用保存的闭包进行调用
        self.observer(event)
    }
    
    /// Erases type of observer and returns canonical observer.
    ///
    /// - returns: type erased observer.
    public func asObserver() -> AnyObserver<Element> {
        self
    }
}

extension AnyObserver {
    /// Collection of `AnyObserver`s
    typealias s = Bag<(Event<Element>) -> Void>
}

extension ObserverType {
    /// Erases type of observer and returns canonical observer.
    ///
    /// - returns: type erased observer.
    public func asObserver() -> AnyObserver<Element> {
        AnyObserver(self)
    }
    
    /// Transforms observer of type R to type E using custom transform method.
    /// Each event sent to result observer is transformed and sent to `self`.
    ///
    /// - returns: observer that transforms events.
    public func mapObserver<Result>(_ transform: @escaping (Result) throws -> Element) -> AnyObserver<Result> {
        AnyObserver { e in
            self.on(e.map(transform))
        }
    }
}
