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
    let queue: DispatchQueue
    // 余地
    let leeway: DispatchTimeInterval
}

/*s
 DispatchQueueConfiguration 就是将 DispatchQueue 的对于 scheduleType 实现代码进行聚拢.
 */
extension DispatchQueueConfiguration {
    
    // 这里的实现思路, 和 OperationQueue 的没有区别.
    func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
        let cancel = SingleAssignmentDisposable()

        self.queue.async {
            if cancel.isDisposed {
                return
            }
            cancel.setDisposable(action(state))
        }

        return cancel
    }

    // 延时执行.
    // 不太明白, 为什么不用 dispatchAfter.
    // 这里就是起了一个定时器, 定时器触发前, 可以进行取消, 定时器触发后, 取消的是 action 对象的返回值.
    // 感觉可以使用上面函数的思路.
    func scheduleRelative<StateType>(_ state: StateType, dueTime: RxTimeInterval, action: @escaping (StateType) -> Disposable) -> Disposable {
        let deadline = DispatchTime.now() + dueTime

        let compositeDisposable = CompositeDisposable()

        let timer = DispatchSource.makeTimerSource(queue: self.queue)
        timer.schedule(deadline: deadline, leeway: self.leeway)

        // TODO:
        // This looks horrible, and yes, it is.
        // It looks like Apple has made a conceptual change here, and I'm unsure why.
        // Need more info on this.
        // It looks like just setting timer to fire and not holding a reference to it
        // until deadline causes timer cancellation.
        var timerReference: DispatchSourceTimer? = timer
        let cancelTimer = Disposables.create {
            timerReference?.cancel()
            timerReference = nil
        }

        timer.setEventHandler(handler: {
            if compositeDisposable.isDisposed {
                return
            }
            _ = compositeDisposable.insert(action(state))
            cancelTimer.dispose()
        })
        timer.resume()

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
        
        // TODO:
        // This looks horrible, and yes, it is.
        // It looks like Apple has made a conceptual change here, and I'm unsure why.
        // Need more info on this.
        // It looks like just setting timer to fire and not holding a reference to it
        // until deadline causes timer cancellation.
        var timerReference: DispatchSourceTimer? = timer
        // timer 的声明周期, 被 cancelTimer 保持着.
        // 只有, cancelTimer 明确的调用 dispose, 才能解除.
        let cancelTimer = Disposables.create {
            timerReference?.cancel()
            timerReference = nil
        }

        // cancelTimer 的生命周期, 又让 timer 进行保持着.
        // cancelTimer 保持着 timer, timer 保持着 cancelTimer. 只有明确的进行 dispose 的调用, 才能打破这层循环引用环.
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
