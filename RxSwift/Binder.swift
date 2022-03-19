//
//  Binder.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/17/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

/*
 Binder 是用来当做 Observer 的.
 它的 On 就是使用调用传递过来的闭包, 一般来说, 就是将数据, 设置到 Base 的某个值上. 
 */
public struct Binder<Value>: ObserverType {
    public typealias Element = Value
    
    private let binding: (Event<Value>) -> Void
    
    // Binding 的逻辑, 一般来说和 UI 相关. 所以, 这里的 scheduler 使用的是 MainScheduler
    // Binding 的真正调用, 是包含在了 Scheduler 的 schedule 逻辑里面的
    // 这里, 和一个 OBJ 绑定的, 用到了 Reactive 中 keypath 的设计了.
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
                    // 这里仅仅是调度执行环境, 没有必要取消. 
                    return Disposables.create()
                }
            case .error(let error):
                rxFatalErrorInDebug("Binding error: \(error)")
            case .completed:
                break
            }
        }
    }
    
    public func on(_ event: Event<Value>) {
        self.binding(event)
    }
    
    public func asObserver() -> AnyObserver<Value> {
        AnyObserver(eventHandler: self.on)
    }
}
