//
//  UIGestureRecognizer+Rx.swift
//  RxCocoa
//
//  Created by Carlos García on 10/6/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(iOS) || os(tvOS)

import UIKit
import RxSwift


/*
 Cocoa 的内部, 不是使用的 Rx 进行的通信. Control, Gesture, BarItem 都在自己的内部, 使用了 Target, Action 的方式进行了存储.
 当用户触发了 UI 事件的时候, 会使用 OC 的查找机制, 触发对应的 Action.
 这是正确的.
 
 rx 并没有和之前的机制做针对, rx 只是统一数据的交互方式. 所以, 只要 target action 能够容纳到 rx 的信号发射机制里面就可以了.
 但是 target 的内存管理是一个问题, rxTarget 的主要目的, 就是解决 target 的内存问题. 通过, 自引用的方式, 将内存自己进行管理. 然后通过 dispose 的方式, 显示的进行切割.
 这和 Sink 里面的处理逻辑也是一样的.
 */
class RxTarget : NSObject, Disposable {
    
    private var retainSelf: RxTarget?
    
    override init() {
        super.init()
        self.retainSelf = self
    }
    
    func dispose() {
        self.retainSelf = nil
    }
}

// 各个 rxTarget 的子类, 都是使用 target - action 的机制. 存储一个闭包, 然后 SEL 就是调用这个闭包.
// 这个闭包, 是外界传入的, 一般来说, 就是发射 next 信号, 把 base 传输出去. 然后, 外界使用 base 进行值的 get.
// BarButtonItemTarget, GestureTarget 都是一样的套路.
final class ControlTarget: RxTarget {
    typealias Callback = (Control) -> Void
    
    let selector: Selector = #selector(ControlTarget.eventHandler(_:))
    
    weak var control: Control?
    let controlEvents: UIControl.Event
    
    var callback: Callback?
    
    init(control: Control, controlEvents: UIControl.Event, callback: @escaping Callback) {
        self.control = control
        self.controlEvents = controlEvents
        self.callback = callback
        
        super.init()
        
        // 在构建方法里面, 进行了 target action 的监听.
        control.addTarget(self, action: selector, for: controlEvents)
    }
    
    @objc func eventHandler(_ sender: Control!) {
        if let callback = self.callback,
           let control = self.control {
            callback(control)
        }
    }
    
    // dispose, super 进行自引用的切除, sub 进行 target action 机制的取消注册.
    override func dispose() {
        super.dispose()
        // 在 dispose 的时候, 解除 target action 的监听状态.
        self.control?.removeTarget(self, action: self.selector, for: self.controlEvents)
        self.callback = nil
    }
}


@objc
final class BarButtonItemTarget: RxTarget {
    typealias Callback = () -> Void
    
    weak var barButtonItem: UIBarButtonItem?
    var callback: Callback!
    
    init(barButtonItem: UIBarButtonItem, callback: @escaping () -> Void) {
        self.barButtonItem = barButtonItem
        self.callback = callback
        super.init()
        barButtonItem.target = self
        barButtonItem.action = #selector(BarButtonItemTarget.action(_:))
    }
    
    override func dispose() {
        super.dispose()
        barButtonItem?.target = nil
        barButtonItem?.action = nil
        
        callback = nil
    }
    
    @objc func action(_ sender: AnyObject) {
        callback()
    }
}

final class GestureTarget<Recognizer: UIGestureRecognizer>: RxTarget {
    
    typealias Callback = (Recognizer) -> Void
    
    let selector = #selector(ControlTarget.eventHandler(_:))
    
    weak var gestureRecognizer: Recognizer?
    var callback: Callback?
    
    init(_ gestureRecognizer: Recognizer, callback: @escaping Callback) {
        self.gestureRecognizer = gestureRecognizer
        self.callback = callback
        
        super.init()
        
        gestureRecognizer.addTarget(self, action: selector)
        
        let method = self.method(for: selector)
        if method == nil {
            fatalError("Can't find method")
        }
    }
    
    @objc func eventHandler(_ sender: UIGestureRecognizer) {
        if let callback = self.callback, let gestureRecognizer = self.gestureRecognizer {
            callback(gestureRecognizer)
        }
    }
    
    override func dispose() {
        super.dispose()
        
        self.gestureRecognizer?.removeTarget(self, action: self.selector)
        self.callback = nil
    }
}

extension Reactive where Base: UIGestureRecognizer {
    
    /// Reactive wrapper for gesture recognizer events.
    public var event: ControlEvent<Base> {
        
        let source: Observable<Base> = Observable.create { [weak control = self.base] observer in
            //
            MainScheduler.ensureRunningOnMainThread()
            
            guard let control = control else {
                observer.on(.completed)
                return Disposables.create()
            }
            
            let observer = GestureTarget(control) { control in
                observer.on(.next(control))
            }
            
            return observer
        }.take(until: deallocated)
        
        return ControlEvent(events: source)
    }
    
}

#endif
