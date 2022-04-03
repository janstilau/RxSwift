//
//  MainScheduler.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Dispatch
#if !os(Linux)
import Foundation
#endif

/*
 Abstracts work that needs to be performed on `DispatchQueue.main`. In case `schedule` methods are called from `DispatchQueue.main`, it will perform action immediately without scheduling.
 
 This scheduler is usually used to perform UI work.
 
 Main scheduler is a specialization of `SerialDispatchQueueScheduler`.
 
 This scheduler is optimized for `observeOn` operator. To ensure observable sequence is subscribed on main thread using `subscribeOn`
 operator please use `ConcurrentMainScheduler` because it is more optimized for that purpose.
 */
public final class MainScheduler : SerialDispatchQueueScheduler {
    
    private let mainQueue: DispatchQueue
    
    let numberEnqueued = AtomicInt(0)
    
    /// Initializes new instance of `MainScheduler`.
    public init() {
        // 固定, 将 queue 变为了 mainqueue.
        // 然后, 将 mainqueue 传入进去.
        self.mainQueue = DispatchQueue.main
        super.init(serialQueue: self.mainQueue)
    }
    
    /// Singleton instance of `MainScheduler`
    public static let instance = MainScheduler()
    
    /// Singleton instance of `MainScheduler` that always schedules work asynchronously
    /// and doesn't perform optimizations for calls scheduled from main queue.
    public static let asyncInstance = SerialDispatchQueueScheduler(serialQueue: DispatchQueue.main)
    
    /// In case this method is called on a background thread it will throw an exception.
    public static func ensureExecutingOnScheduler(errorMessage: String? = nil) {
        if !DispatchQueue.isMain {
            rxFatalError(errorMessage ?? "Executing on background thread. Please use `MainScheduler.instance.schedule` to schedule work on main thread.")
        }
    }
    
    /// In case this method is running on a background thread it will throw an exception.
    public static func ensureRunningOnMainThread(errorMessage: String? = nil) {
#if !os(Linux) // isMainThread is not implemented in Linux Foundation
        guard Thread.isMainThread else {
            rxFatalError(errorMessage ?? "Running on background thread.")
        }
#endif
    }
    
    override func scheduleInternal<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
        let previousNumberEnqueued = increment(self.numberEnqueued)
        
        // 如果, 当前的就是 MainQueue, 那么直接执行 action.
        if DispatchQueue.isMain && previousNumberEnqueued == 0 {
            let disposable = action(state)
            decrement(self.numberEnqueued)
            return disposable
        }
        
        let cancel = SingleAssignmentDisposable()
        
        // 否则, 就把任务添加到 MainQueue 的末尾.
        // SingleAssignmentDisposable 的作用, 如果, action 没有实际发挥作用, 这就是一个标志为. 当调度到这个命令对象的时候, 直接不执行就好了.
        // 如果 action 已经实际调用了, 那么就保存一下返回的 Disposable 的值.
        self.mainQueue.async {
            if !cancel.isDisposed {
                cancel.setDisposable(action(state))
            }
            
            decrement(self.numberEnqueued)
        }
        
        return cancel
    }
}
