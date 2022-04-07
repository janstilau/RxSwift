//
//  DispatchQueueConfiguration.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 7/23/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Dispatch
import Foundation

struct DispatchQueueConfiguration {
    // 在定义里面, 并没有区分这个 queue 是否是串行队列.
    let queue: DispatchQueue
    let leeway: DispatchTimeInterval
}

/*s
 DispatchQueueConfiguration 就是将 DispatchQueue 的对于 scheduleType 实现代码进行聚拢.
 */
extension DispatchQueueConfiguration {
    
    // 这里的实现思路, 和 OperationQueue 的没有区别.
    func schedule<StateType>(_ state: StateType,
                             action: @escaping (StateType) -> Disposable) -> Disposable {
        let cancel = SingleAssignmentDisposable()
        self.queue.async {
            // 这是一个异步操作, 所以有可能, queue 中的任务没有执行之前, cancel 已经被 dispose 了
            // 如果在任务开始的时候, cancel 已经被触发, 就不进行 action 的触发.
            // 否则, 触发 action, cancel 中存储返回的 subscription.
            if cancel.isDisposed {
                return
            }
            cancel.setDisposable(action(state))
        }
        return cancel
    }

    // 延时执行.
    // 实现的思路和上面的函数, 没有区别, 只不过是使用定时触发的逻辑了.
    func scheduleRelative<StateType>(_ state: StateType, dueTime: RxTimeInterval, action: @escaping (StateType) -> Disposable) -> Disposable {
        let deadline = DispatchTime.now() + dueTime

        let compositeDisposable = CompositeDisposable()

        let timer = DispatchSource.makeTimerSource(queue: self.queue)
        timer.schedule(deadline: deadline, leeway: self.leeway)

        // 这里会有一个循环引用.
        // 在 timer fire 的时候可以打破这个循环引用. 在 subscription dispose 的时候, 也可以打破这个循环引用.
        var timerReference: DispatchSourceTimer? = timer
        let cancelTimer = Disposables.create {
            timerReference?.cancel()
            timerReference = nil
        }

        timer.setEventHandler(handler: {
            if compositeDisposable.isDisposed {
                return
            }
            // 使得, compositeDisposable 有了取消 action 触发的异步操作的能力.
            _ = compositeDisposable.insert(action(state))
            // cancelTimer 还是在 compositeDisposable 里面, 这是没有问题的, 因为在 cancelTimer dispose 之后, 会有状态为的变化. 所以重复调用不会引起重复的 dispose.
            cancelTimer.dispose()
        })
        timer.resume()

        // 使得, compositeDisposable 有了取消调度的能力.
        _ = compositeDisposable.insert(cancelTimer)

        return compositeDisposable
    }

    func schedulePeriodic<StateType>(_ state: StateType,
                                     startAfter: RxTimeInterval,
                                     period: RxTimeInterval,
                                     action: @escaping (StateType) -> StateType) -> Disposable {
        // 使用 GCD 完成了 Timer 的构建.
        let initial = DispatchTime.now() + startAfter

        var timerState = state

        let timer = DispatchSource.makeTimerSource(queue: self.queue)
        timer.schedule(deadline: initial, repeating: period, leeway: self.leeway)
        
        var timerReference: DispatchSourceTimer? = timer
        let cancelTimer = Disposables.create {
            timerReference?.cancel()
            timerReference = nil
        }

        // 和上面相比, timer 触发的时候, 取消了 timer 取消的操作.
        // 只能通过 cancelTimer 进行定时器的取消. 
        timer.setEventHandler(handler: {
            if cancelTimer.isDisposed {
                return
            }
            timerState = action(timerState)
        })
        timer.resume()
        
        // cancelTimer 引用着 Timer, CancelTiemr 的 dispose, 可以促使 Timer 的取消, 并且打破对于 Timer 的引用.
        return cancelTimer
    }
}
