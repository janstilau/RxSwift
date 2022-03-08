//
//  SerialDispatchQueueScheduler.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Dispatch
import Foundation

/*
Abstracts the work that needs to be performed on a specific `dispatch_queue_t`.
It will make sure that even if concurrent dispatch queue is passed, it's transformed into a serial one.

It is extremely important that this scheduler is serial, because
certain operator perform optimizations that rely on that property.

Because there is no way of detecting is passed dispatch queue serial or
concurrent, for every queue that is being passed, worst case (concurrent)
will be assumed, and internal serial proxy dispatch queue will be created.

This scheduler can also be used with internal serial queue alone.

In case some customization need to be made on it before usage,
internal serial queue can be customized using `serialQueueConfiguration`
callback.
*/

public class SerialDispatchQueueScheduler : SchedulerType {
    
    public typealias TimeInterval = Foundation.TimeInterval
    public typealias Time = Date
    
    /// - returns: Current time.
    public var now : Date {
        Date()
    }

    let configuration: DispatchQueueConfiguration
    
    // 如果, 直接传递过来一个 DispatchQueue, 就直接使用过了.
    init(serialQueue: DispatchQueue, leeway: DispatchTimeInterval = DispatchTimeInterval.nanoseconds(0)) {
        self.configuration = DispatchQueueConfiguration(queue: serialQueue, leeway: leeway)
    }

    // 内部创建一个串行队列.
    public convenience init(internalSerialQueueName: String, serialQueueConfiguration: ((DispatchQueue) -> Void)? = nil, leeway: DispatchTimeInterval = DispatchTimeInterval.nanoseconds(0)) {
        // 内部创建一个 DispatchQueue
        let queue = DispatchQueue(label: internalSerialQueueName, attributes: [])
        serialQueueConfiguration?(queue)
        self.init(serialQueue: queue, leeway: leeway)
    }
    
    // 内部创建一个串行队列.
    public convenience init(queue: DispatchQueue, internalSerialQueueName: String, leeway: DispatchTimeInterval = DispatchTimeInterval.nanoseconds(0)) {
        // Swift 3.0 IUO
        let serialQueue = DispatchQueue(label: internalSerialQueueName,
                                        attributes: [],
                                        target: queue)
        self.init(serialQueue: serialQueue, leeway: leeway)
    }

    public final func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
        self.scheduleInternal(state, action: action)
    }

    func scheduleInternal<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
        self.configuration.schedule(state, action: action)
    }

    public final func scheduleRelative<StateType>(_ state: StateType, dueTime: RxTimeInterval, action: @escaping (StateType) -> Disposable) -> Disposable {
        self.configuration.scheduleRelative(state, dueTime: dueTime, action: action)
    }
    
    public func schedulePeriodic<StateType>(_ state: StateType, startAfter: RxTimeInterval, period: RxTimeInterval, action: @escaping (StateType) -> StateType) -> Disposable {
        // 直接, 使用了 DispatchQueueConfiguration 完成了定时器的工作. 
        self.configuration.schedulePeriodic(state, startAfter: startAfter, period: period, action: action)
    }
}
