//
//  DelaySubscription.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {

    /*
     Time shifts the observable sequence by delaying the subscription with the specified relative time duration, using the specified scheduler to run timers.
     */
    public func delaySubscription(_ dueTime: RxTimeInterval, scheduler: SchedulerType)
        -> Observable<Element> {
        DelaySubscription(source: self.asObservable(), dueTime: dueTime, scheduler: scheduler)
    }
}

// 完全的中介者.
final private class DelaySubscriptionSink<Observer: ObserverType>
    : Sink<Observer>, ObserverType {
    typealias Element = Observer.Element 
    
    func on(_ event: Event<Element>) {
        self.forwardOn(event)
        if event.isStopEvent {
            self.dispose()
        }
    }
    
}

final private class DelaySubscription<Element>: Producer<Element> {
    private let source: Observable<Element>
    private let dueTime: RxTimeInterval
    private let scheduler: SchedulerType
    
    init(source: Observable<Element>, dueTime: RxTimeInterval, scheduler: SchedulerType) {
        self.source = source
        self.dueTime = dueTime
        self.scheduler = scheduler
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = DelaySubscriptionSink(observer: observer, cancel: cancel)
        // 将, subscribe 这件事, 进行了延后处理.
        // 在 scheduleRelative 中的返回值中, 首先是定时器的取消逻辑, 定时器触发了之后, 会替换为 self.source.subscribe(sink) 的取消逻辑. 
        let subscription = self.scheduler.scheduleRelative((), dueTime: self.dueTime) { _ in
            return self.source.subscribe(sink)
        }
        return (sink: sink, subscription: subscription)
    }
}
