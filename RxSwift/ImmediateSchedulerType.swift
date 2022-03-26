//
//  ImmediateSchedulerType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 5/31/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 调度, 就是在 on 接收到信号之后, 保存状态, 在另外的一个运行环境, 进行操作, 然后将结果移交给后续节点.
 一般来说, 都是直接交给了后续节点.
 
 调度本身可以取消, 指定操作也可以进行取消.
 所以, 这个函数的返回值, subscription 会有一个 cancel 替换的过程.
 */
public protocol ImmediateSchedulerType {
    /**
    Schedules an action to be executed immediately.
    */
    func schedule<StateType>(_ state: StateType,
                             action: @escaping (StateType) -> Disposable) -> Disposable
}

extension ImmediateSchedulerType {
    // Rx 里面, 有些设计的很栏, 一点不利于思考. 
    /*
    Schedules an action to be executed recursively.
    
    - parameter state: State passed to the action to be executed.
    - parameter action: Action to execute recursively. The last parameter passed to the action is used to trigger recursive scheduling of the action, passing in recursive invocation state.
    - returns: The disposable object used to cancel the scheduled action (best effort).
    */
    public func scheduleRecursive<State>(_ state: State,
                                         action: @escaping (_ state: State, _ recurse: (State) -> Void) -> Void)
    -> Disposable {
        let recursiveScheduler = RecursiveImmediateScheduler(action: action, scheduler: self)
        recursiveScheduler.schedule(state)
        return Disposables.create(with: recursiveScheduler.dispose)
    }
}
