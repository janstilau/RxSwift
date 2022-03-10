//
//  AsyncLock.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 In case nobody holds this lock, the work will be queued and executed immediately
 on thread that is requesting lock.
 
 In case there is somebody currently holding that lock, action will be enqueued.
 When owned of the lock finishes with it's processing, it will also execute
 and pending work.
 
 That means that enqueued work could possibly be executed later on a different thread.
 */

// 这个数据结构保证了, 只会在一个线程在执行任务, 但是具体在哪个线程不一定.
// 这个类, 仅仅在 TailRecursiveSink 中被使用了
final class AsyncLock<I: InvocableType>
: Disposable
, Lock
, SynchronizedDisposeType {
    
    typealias Action = () -> Void
    
    private var _lock = SpinLock()
    
    private var queue: Queue<I> = Queue(capacity: 0)
    
    private var isExecuting: Bool = false
    private var hasFaulted: Bool = false
    
    func lock() {
        self._lock.lock()
    }
    
    func unlock() {
        self._lock.unlock()
    }
    
    private func enqueue(_ action: I) -> I? {
        self.lock(); defer { self.unlock() }
        
        if self.hasFaulted {
            return nil
        }
        
        if self.isExecuting {
            self.queue.enqueue(action)
            return nil
        }
        
        self.isExecuting = true
        return action
    }
    
    private func dequeue() -> I? {
        self.lock(); defer { self.unlock() }
        
        if !self.queue.isEmpty {
            return self.queue.dequeue()
        } else {
            self.isExecuting = false
            return nil
        }
    }
    
    func invoke(_ action: I) {
        
        let firstEnqueuedAction = self.enqueue(action)
        
        // 如果有返回值, 那么就是当前没有积累的任务, 直接执行当前的任务.
        // 但是, 执行当前任务的时候, 可能会有新的 Invoke 被调用. 所以在之后, 会有一个 while 循环, 来清空这个期间积累的任务.
        // 在清空之后, 才会将 isExecuting 进行清空.
        if let firstEnqueuedAction = firstEnqueuedAction {
            firstEnqueuedAction.invoke()
        } else {
            // action is enqueued, it's somebody else's concern now
            return
        }
        
        while true {
            let nextAction = self.dequeue()
            
            if let nextAction = nextAction {
                nextAction.invoke()
            } else {
                return
            }
        }
    }
    
    func dispose() {
        self.synchronizedDispose()
    }
    
    func synchronized_dispose() {
        self.queue = Queue(capacity: 0)
        self.hasFaulted = true
    }
}
