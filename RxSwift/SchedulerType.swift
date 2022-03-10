//
//  SchedulerType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Dispatch
import Foundation

public typealias RxTimeInterval = DispatchTimeInterval
public typealias RxTime = Date

public protocol SchedulerType: ImmediateSchedulerType {
    
    /// - returns: Current time.
    var now : RxTime {
        get
    }
    
    // 定时多少时间之后, 进行 action 的触发
    func scheduleRelative<StateType>(_ state: StateType, dueTime: RxTimeInterval, action: @escaping (StateType) -> Disposable) -> Disposable
    
    // 定时多少时间之后, 进行 action 的周期性的触发.
    func schedulePeriodic<StateType>(_ state: StateType, startAfter: RxTimeInterval, period: RxTimeInterval, action: @escaping (StateType) -> StateType) -> Disposable
}

extension SchedulerType {
    
    /**
     Periodic task will be emulated using recursive scheduling.
     
     - parameter state: Initial state passed to the action upon the first iteration.
     - parameter startAfter: Period after which initial work should be run.
     - parameter period: Period for running the work periodically.
     - returns: The disposable object used to cancel the scheduled recurring action (best effort).
     */
    public func schedulePeriodic<StateType>(_ state: StateType, startAfter: RxTimeInterval, period: RxTimeInterval, action: @escaping (StateType) -> StateType) -> Disposable {
        let schedule = SchedulePeriodicRecursive(scheduler: self, startAfter: startAfter, period: period, action: action, state: state)
        
        return schedule.start()
    }
    
    func scheduleRecursive<State>(_ state: State, dueTime: RxTimeInterval, action: @escaping (State, AnyRecursiveScheduler<State>) -> Void) -> Disposable {
        let scheduler = AnyRecursiveScheduler(scheduler: self, action: action)
        
        scheduler.schedule(state, dueTime: dueTime)
        
        return Disposables.create(with: scheduler.dispose)
    }
}
