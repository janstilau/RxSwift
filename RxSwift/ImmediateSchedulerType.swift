//
//  ImmediateSchedulerType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 5/31/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// 有一个数据, 以及对于这个数据的操作, 调度这个操作, 而不是立马进行触发.
// 调度这个动作, 本身可以取消. 如果动作执行了, 那么执行后的返回值, 可以取消这个动作产生的序列.
public protocol ImmediateSchedulerType {
    /**
    Schedules an action to be executed immediately.
    */
    func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable
}

extension ImmediateSchedulerType {
    /**
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
