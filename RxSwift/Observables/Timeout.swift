//
//  Timeout.swift
//  RxSwift
//
//  Created by Tomi Koskinen on 13/11/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    
    /*
     Applies a timeout policy for each element in the observable sequence. If the next element isn't received within the specified timeout duration starting from its predecessor, a TimeoutError is propagated to the observer.
     */
    public func timeout(_ dueTime: RxTimeInterval,
                        scheduler: SchedulerType)
    -> Observable<Element> {
        return Timeout(source: self.asObservable(),
                       dueTime: dueTime,
                       other: Observable.error(RxError.timeout),
                       scheduler: scheduler)
    }
    
    /*
     Applies a timeout policy for each element in the observable sequence, using the specified scheduler to run timeout timers. If the next element isn't received within the specified timeout duration starting from its predecessor, the other observable sequence is used to produce future messages from that point on.
     */
    public func timeout<Source: ObservableConvertibleType>(_ dueTime: RxTimeInterval,
                                                           other: Source,
                                                           scheduler: SchedulerType)
    -> Observable<Element> where Element == Source.Element {
        return Timeout(source: self.asObservable(), dueTime: dueTime, other: other.asObservable(), scheduler: scheduler)
    }
}

final private class TimeoutSink<Observer: ObserverType>: Sink<Observer>, LockOwnerType, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = Timeout<Element>
    
    private let parent: Parent
    
    let lock = RecursiveLock()
    
    private let timerD = SerialDisposable()
    private let subscription = SerialDisposable()
    
    private var id = 0
    private var switched = false
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    func run() -> Disposable {
        let original = SingleAssignmentDisposable()
        self.subscription.disposable = original
        self.createTimeoutTimer()
        original.setDisposable(self.parent.source.subscribe(self))
        return Disposables.create(subscription, timerD)
    }
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            var onNextWins = false
            
            self.lock.performLocked {
                onNextWins = !self.switched
                if onNextWins {
                    self.id = self.id &+ 1
                }
            }
            
            if onNextWins {
                self.forwardOn(event)
                // 时间节点内, 直接替换 Timer.
                self.createTimeoutTimer()
            }
        case .error, .completed:
            var onEventWins = false
            
            self.lock.performLocked {
                onEventWins = !self.switched
                if onEventWins {
                    self.id = self.id &+ 1
                }
            }
            
            if onEventWins {
                self.forwardOn(event)
                self.dispose()
            }
        }
    }
    
    private func createTimeoutTimer() {
        if self.timerD.isDisposed {
            return
        }
        
        let nextTimer = SingleAssignmentDisposable()
        self.timerD.disposable = nextTimer
        
        let disposeSchedule = self.parent.scheduler.scheduleRelative(self.id, dueTime: self.parent.dueTime) { state in
            
            var timerWins = false
            
            self.lock.performLocked {
                self.switched = (state == self.id)
                // 相同, 就是超时了.
                timerWins = self.switched
            }
            
            if timerWins {
                // 时间到了, 就替换 Sourcer, 在这个替换过程中, 会有 dispose 的调用.
                self.subscription.disposable = self.parent.other.subscribe(self.forwarder())
            }
            
            return Disposables.create()
        }
        
        nextTimer.setDisposable(disposeSchedule)
    }
}

// Producer 仅仅是做记录的工作, 真正的在响应链条里面起作用的, 是 Sink 各个节点.
final private class Timeout<Element>: Producer<Element> {
    fileprivate let source: Observable<Element>
    fileprivate let dueTime: RxTimeInterval
    fileprivate let other: Observable<Element>
    fileprivate let scheduler: SchedulerType
    
    init(source: Observable<Element>, dueTime: RxTimeInterval, other: Observable<Element>, scheduler: SchedulerType) {
        self.source = source
        self.dueTime = dueTime
        self.other = other
        self.scheduler = scheduler
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = TimeoutSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}
