//
//  Binder.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/17/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

/*
 Binder 是用来当做 Observer 的.
 */
public struct Binder<Value>: ObserverType {
    public typealias Element = Value
    
    // binding 的设置, 是在初始化方法里面的. 是一个 Private 属性.
    private let binding: (Event<Value>) -> Void
    
    // Binding 的逻辑, 一般来说和 UI 相关. 所以, 这里的 scheduler 使用的是 MainScheduler
    // Binding 的主要逻辑, 是藏一个 UI 对象, 然后藏一个闭包, 这个闭包是当信号来临之后, 应该怎么操作这个藏起来的 UI 对象.
    //
    public init<Target: AnyObject>(_ target: Target,
                                   scheduler: ImmediateSchedulerType = MainScheduler(),
                                   binding: @escaping (Target, Value) -> Void) {
        weak var weakTarget = target
        
        self.binding = { event in
            switch event {
            case .next(let element):
                // 当, 信号来临的时候, 使用存储的 Binding 闭包, 来对 UI 进行更新.
                // Binder 的存在, 使得 scheduler.schedule 一定会触发.
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
