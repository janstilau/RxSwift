//
//  Binder.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/17/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

/*
    Binder 传入一个对象, 以及当数据发送过来的时候, 应该如何处理这个数据, 一般来说, 是利用这个数据进行 Target 的操作. 这也就是 Bind 的命名的含义.
 */
public struct Binder<Value>: ObserverType {
    public typealias Element = Value
    
    private let binding: (Event<Value>) -> Void
    
    // Binding 的逻辑, 一般来说和 UI 相关. 所以, 这里的 scheduler 使用的是 MainScheduler
    // Binding 的真正调用, 是包含在了 Scheduler 的 schedule 逻辑里面的
    public init<Target: AnyObject>(_ target: Target,
                                   scheduler: ImmediateSchedulerType = MainScheduler(),
                                   binding: @escaping (Target, Value) -> Void) {
        weak var weakTarget = target
        
        self.binding = { event in
            switch event {
            case .next(let element):
                _ = scheduler.schedule(element) { element in
                    if let target = weakTarget {
                        binding(target, element)
                    }
                    // 仅仅是做事件调度, 没有必要进行取消, 直接返回一个 FakeCancle 对象.
                    return Disposables.create()
                }
            case .error(let error):
                rxFatalErrorInDebug("Binding error: \(error)")
            case .completed:
                break
            }
        }
    }
    
    /// Binds next element to owner view as described in `binding`.
    public func on(_ event: Event<Value>) {
        self.binding(event)
    }
    
    /// Erases type of observer.
    ///
    /// - returns: type erased observer.
    public func asObserver() -> AnyObserver<Value> {
        AnyObserver(eventHandler: self.on)
    }
}
