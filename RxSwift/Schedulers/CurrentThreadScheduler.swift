//
//  CurrentThreadScheduler.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/30/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Dispatch
import Foundation

#if os(Linux)
fileprivate enum CurrentThreadSchedulerQueueKey {
    fileprivate static let instance = "RxSwift.CurrentThreadScheduler.Queue"
}
#else
private class CurrentThreadSchedulerQueueKey: NSObject, NSCopying {
    static let instance = CurrentThreadSchedulerQueueKey()
    private override init() {
        super.init()
    }
    
    override var hash: Int {
        return 0
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
}
#endif

/// Represents an object that schedules units of work on the current thread.
///
/// This is the default scheduler for operators that generate elements.
///
/// This scheduler is also sometimes called `trampoline scheduler`.

public class CurrentThreadScheduler : ImmediateSchedulerType {
    typealias ScheduleQueue = RxMutableBox<Queue<ScheduledItemType>>
    
    /// The singleton instance of the current thread scheduler.
    public static let instance = CurrentThreadScheduler()
    
    private static var scheduleInProgressSentinel: UnsafeRawPointer = { () -> UnsafeRawPointer in
        return UnsafeRawPointer(UnsafeMutablePointer<Int>.allocate(capacity: 1))
    }()
    
    static var queue : ScheduleQueue? {
        get {
            return Thread.getThreadLocalStorageValueForKey(CurrentThreadSchedulerQueueKey.instance)
        }
        set {
            Thread.setThreadLocalStorageValue(newValue, forKey: CurrentThreadSchedulerQueueKey.instance)
        }
    }
    
    private static var isScheduleRequiredKey: pthread_key_t = { () -> pthread_key_t in
        let key = UnsafeMutablePointer<pthread_key_t>.allocate(capacity: 1)
        defer { key.deallocate() }
        
        guard pthread_key_create(key, nil) == 0 else {
            rxFatalError("isScheduleRequired key creation failed")
        }
        return key.pointee
    }()
    
    // Gets a value that indicates whether the caller must call a `schedule` method.
    public static private(set) var isScheduleRequired: Bool {
        get {
            return pthread_getspecific(CurrentThreadScheduler.isScheduleRequiredKey) == nil
        }
        
        set(isScheduleRequired) {
            if pthread_setspecific(CurrentThreadScheduler.isScheduleRequiredKey,
                                   isScheduleRequired ? nil : scheduleInProgressSentinel) != 0 {
                rxFatalError("pthread_setspecific failed")
            }
        }
    }
    
    /*
     Schedules an action to be executed as soon as possible on current thread.
     
     If this method is called on some thread that doesn't have `CurrentThreadScheduler` installed, scheduler will be
     automatically installed and uninstalled after all work is performed.
     */
    public func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
        
        /*
         
         Scheduler.CurrentThread.Schedule(() =>
         {
             Console.WriteLine("A");

             Scheduler.CurrentThread.Schedule(() =>
             {
                 Console.WriteLine("C");
             });

             Scheduler.CurrentThread.Schedule(() =>
             {
                 Console.WriteLine("D");
             });

             Console.WriteLine("B");
         });
         */
        // 这里的代码, 是为了以上的嵌套调用准备的.
        // 如果不用现在的这种设计, 就会 ACDB 这样执行, 而现在, 会是 ABCD 这样执行.
        if CurrentThreadScheduler.isScheduleRequired {
            CurrentThreadScheduler.isScheduleRequired = false
            
            let disposable = action(state)
            
            defer {
                CurrentThreadScheduler.isScheduleRequired = true
                CurrentThreadScheduler.queue = nil
            }
            
            guard let queue = CurrentThreadScheduler.queue else {
                return disposable
            }
            
            while let latest = queue.value.dequeue() {
                if latest.isDisposed {
                    continue
                }
                latest.invoke()
            }
            
            return disposable
        }
        
        let existingQueue = CurrentThreadScheduler.queue
        
        let queue: RxMutableBox<Queue<ScheduledItemType>>
        if let existingQueue = existingQueue {
            queue = existingQueue
        } else {
            queue = RxMutableBox(Queue<ScheduledItemType>(capacity: 1))
            CurrentThreadScheduler.queue = queue
        }
        
        let scheduledItem = ScheduledItem(action: action, state: state)
        queue.value.enqueue(scheduledItem)
        
        return scheduledItem
    }
}
