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
    
    
    /*
     一定要记住, 每个 Subscribe, 其实都是建立一条新的响应通道.
     btn.rx.tap.subscribe
     btn.rx.tap.subscribe
     上面的两次调用, 每次都是完整的链条上 Producer 的 subscribe 方法的调用.
     所以, 到最后 btn 的 allTargets 里面会有两个 Target 而不是一个.
     */
    public func controlEvent(_ controlEvents: UIControl.Event) -> ControlEvent<()> {
        
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
            
            // Disposables.create(with: controlTarget.dispose)
            // 这句代码, 掌管了 ControlTarget 的生命周期 .
            return Disposables.create(with: controlTarget.dispose)
        }.take(until: deallocated)
        
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
        
        // 这个闭包, 是在 controlProperty 被调用的时候就生成的, 只不过它的调用, 是在实际被注册的时候才发生. 在这个时候, base 的值, 已经传递给了 weak weakControl
        let source: Observable<T> = Observable.create { [weak weakControl = base] observer in
            guard let control = weakControl else {
                observer.on(.completed)
                return Disposables.create()
            }
            
            // 先会读取当前的 Control 上面的数据, 传递给后续节点使用.
            observer.on(.next(getter(control)))
            
            // 在 ControlTarget 的内部, 进行了自我的引用循环管理. 所以, 会一直存在, 直到 controlTarget.dispose 被调用.
            // 在 ControlTarget 的内部, 每次事件触发, 都会调用传递过去的闭包被调用. 而这个闭包, 就是传递 next 到后面的处理节点.
            let controlTarget = ControlTarget(control: control,
                                              controlEvents: editingEvents) { _ in
                if let control = weakControl {
                    observer.on(.next(getter(control)))
                }
            }
            
            return Disposables.create(with: controlTarget.dispose)
        }.take(until: deallocated)
        
        // Binder, 存储一个 Setter 闭包, 在 on 函数里面, 使用这个 Setter 闭包, 来处理 next(value) 的值. 
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
