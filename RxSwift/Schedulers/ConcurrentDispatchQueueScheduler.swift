//
//  ConcurrentDispatchQueueScheduler.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 7/5/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Dispatch
import Foundation

/// Abstracts the work that needs to be performed on a specific `dispatch_queue_t`. You can also pass a serial dispatch queue, it shouldn't cause any problems.
///
/// This scheduler is suitable when some work needs to be performed in background.


// ConcurrentDispatchQueueScheduler 和串行的实现没有任何的区别.
// 所以, 在传入 DispatchQueue 的时候, 其实是需要创建者保证, 传入的是一个符合类定义场景的 queue 才合适.
public class ConcurrentDispatchQueueScheduler: SchedulerType {
    public typealias TimeInterval = Foundation.TimeInterval
    public typealias Time = Date
    
    public var now : Date {
        Date()
    }
    
    // DispatchQueueConfiguration 名称超级栏, 应该叫做 dispatchQueue scheduler.
    let configuration: DispatchQueueConfiguration
    
    /// Constructs new `ConcurrentDispatchQueueScheduler` that wraps `queue`.
    ///
    /// - parameter queue: Target dispatch queue.
    /// - parameter leeway: The amount of time, in nanoseconds, that the system will defer the timer.
    public init(queue: DispatchQueue,
                leeway: DispatchTimeInterval = DispatchTimeInterval.nanoseconds(0)) {
        self.configuration = DispatchQueueConfiguration(queue: queue, leeway: leeway)
    }
    
    /// Convenience init for scheduler that wraps one of the global concurrent dispatch queues.
    ///
    /// - parameter qos: Target global dispatch queue, by quality of service class.
    /// - parameter leeway: The amount of time, in nanoseconds, that the system will defer the timer.
    public convenience init(qos: DispatchQoS, leeway: DispatchTimeInterval = DispatchTimeInterval.nanoseconds(0)) {
        self.init(queue: DispatchQueue(
            label: "rxswift.queue.\(qos)",
            qos: qos,
            attributes: [DispatchQueue.Attributes.concurrent],
            target: nil),
                  leeway: leeway
        )
    }
    
    // 所有的对于 schedule 的操作, 全部交给了 configuration 来处理. 
    /*
     Schedules an action to be executed immediately.
     */
    public final func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
        self.configuration.schedule(state, action: action)
    }
    
    /*
     Schedules an action to be executed.
     */
    public final func scheduleRelative<StateType>(_ state: StateType, dueTime: RxTimeInterval, action: @escaping (StateType) -> Disposable) -> Disposable {
        self.configuration.scheduleRelative(state, dueTime: dueTime, action: action)
    }
    
    /*
     Schedules a periodic piece of work.
     */
    public func schedulePeriodic<StateType>(_ state: StateType, startAfter: RxTimeInterval, period: RxTimeInterval, action: @escaping (StateType) -> StateType) -> Disposable {
        self.configuration.schedulePeriodic(state, startAfter: startAfter, period: period, action: action)
    }
}
