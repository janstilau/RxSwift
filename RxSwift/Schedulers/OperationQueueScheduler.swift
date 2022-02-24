//
//  OperationQueueScheduler.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/4/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Dispatch
import Foundation

/// Abstracts the work that needs to be performed on a specific `NSOperationQueue`.
///
/// This scheduler is suitable for cases when there is some bigger chunk of work that needs to be performed in background and you want to fine tune concurrent processing using `maxConcurrentOperationCount`.
public class OperationQueueScheduler: ImmediateSchedulerType {
    
    public let operationQueue: OperationQueue
    public let queuePriority: Operation.QueuePriority
    
    /// Constructs new instance of `OperationQueueScheduler` that performs work on `operationQueue`.
    ///
    /// - parameter operationQueue: Operation queue targeted to perform work on.
    /// - parameter queuePriority: Queue priority which will be assigned to new operations.
    public init(operationQueue: OperationQueue, queuePriority: Operation.QueuePriority = .normal) {
        self.operationQueue = operationQueue
        self.queuePriority = queuePriority
    }
    
    /**
     Schedules an action to be executed recursively.
     
     - parameter state: State passed to the action to be executed.
     - parameter action: Action to execute recursively. The last parameter passed to the action is used to trigger recursive scheduling of the action, passing in recursive invocation state.
     - returns: The disposable object used to cancel the scheduled action (best effort).
     */
    
    /*
     有了数据, 有了相关的动作, 但是不能立马执行, 而是调度到特定的时间, 或者线程执行.
     调度这件事本身需要可以需求, 执行的动作, 可能还是一个异步操作, 也可以取消.
     
     OperationQueue 的实现, 就是包装一层. 然后将包装的 Operation 放置到 Queue 里面等待调用
     
     SingleAssignmentDisposable 有两个作用.
     如果, Queue 执行之前就 Dispose 了, 那么 action 就不操作, 相当于取消了调度.
     如果, action 执行之后再进行 dispose, 那么 SingleAssignmentDisposable 的 dispose, 就是取消 action 产生的异步操作了.
     */
    public func schedule<StateType>(_ state: StateType,
                                    action: @escaping (StateType) -> Disposable) -> Disposable {
        let cancel = SingleAssignmentDisposable()
        let operation = BlockOperation {
            if cancel.isDisposed {
                return
            }
            cancel.setDisposable(action(state))
        }
        
        operation.queuePriority = self.queuePriority
        
        self.operationQueue.addOperation(operation)
        
        return cancel
    }
    
}
