//
//  UIControl+Rx.swift
//  RxCocoa
//
//  Created by Daniel Tartaglia on 5/23/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(iOS) || os(tvOS)

import RxSwift
import UIKit

extension Reactive where Base: UIControl {
    /// Reactive wrapper for target action pattern.
    ///
    /// - parameter controlEvents: Filter for observed event types.
    public func controlEvent(_ controlEvents: UIControl.Event) -> ControlEvent<()> {
        
        // 原来还能 [weak control = self.base] 这样的赋值.
        // 在捕获列表里面, 标明了, 就是在使用值语义的捕获.
        let source: Observable<Void> = Observable.create { [weak control = self.base] observer in
            
            guard let control = control else {
                observer.on(.completed)
                return Disposables.create()
            }
            
            // 在这里, 创建一个 ControlTarget. ControlTarget 的 target action 触发之后, 会触发 observer.on
            // 而返回的 subscription, 则是进行 controlTarget 的取消注册. 和循环引用删除.
            let controlTarget = ControlTarget(control: control, controlEvents: controlEvents) { _ in
                observer.on(.next(()))
            }
            
            return Disposables.create(with: controlTarget.dispose)
        }
            .take(until: deallocated)
        
        return ControlEvent(events: source)
    }
    
    /// Creates a `ControlProperty` that is triggered by target/action pattern value updates.
    ///
    /// - parameter controlEvents: Events that trigger value update sequence elements.
    /// - parameter getter: Property value getter.
    /// - parameter setter: Property value setter.
    public func controlProperty<T>(
        editingEvents: UIControl.Event,
        getter: @escaping (Base) -> T,
        setter: @escaping (Base, T) -> Void
    ) -> ControlProperty<T> {
        
        // 当, 事件发生是, 会发射一个信号. 这个信号里面的内容,  就是 get 函数提供的个.
        let source: Observable<T> = Observable.create { [weak weakControl = base] observer in
            guard let control = weakControl else {
                observer.on(.completed)
                return Disposables.create()
            }
            
            // 在最开始的时候, 会发送一个信号, 将 Control 当前的数据传递过去.
            observer.on(.next(getter(control)))
            
            // 创建一个 ControlTarget, 会在每次事件触发之后, 发射信号给后方. 
            let controlTarget = ControlTarget(control: control, controlEvents: editingEvents) { _ in
                if let control = weakControl {
                    observer.on(.next(getter(control)))
                }
            }
            
            return Disposables.create(with: controlTarget.dispose)
        }.take(until: deallocated)
        
        let bindingObserver = Binder(base, binding: setter)
        
        return ControlProperty<T>(values: source, valueSink: bindingObserver)
    }
    
    /// This is a separate method to better communicate to public consumers that
    /// an `editingEvent` needs to fire for control property to be updated.
    internal func controlPropertyWithDefaultEvents<T>(
        editingEvents: UIControl.Event = [.allEditingEvents, .valueChanged],
        getter: @escaping (Base) -> T,
        setter: @escaping (Base, T) -> Void
    ) -> ControlProperty<T> {
        return controlProperty(
            editingEvents: editingEvents,
            getter: getter,
            setter: setter
        )
    }
}

#endif
