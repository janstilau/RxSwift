//
//  SubscribeOn.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    /*
     Wraps the source sequence in order to run its subscription and unsubscription logic on the specified
     scheduler.
     
     This operation is not commonly used.
     
     This only performs the side-effects of subscription and unsubscription on the specified scheduler.
     
     In order to invoke observer callbacks on a `scheduler`, use `observeOn`.
     */
    // SubscribeOn 表示的是, 注册这个行为, 应该被 scheduler 调度.
    // ObserverOn 表示的是, 事件的后续处理, 应该被 scheduler 调度.
    
    public func subscribe(on scheduler: ImmediateSchedulerType)
    -> Observable<Element> {
        SubscribeOn(source: self, scheduler: scheduler)
    }
}

final private class SubscribeOnSink<Ob: ObservableType, Observer: ObserverType>: Sink<Observer>, ObserverType where Ob.Element == Observer.Element {
    typealias Element = Observer.Element
    typealias Parent = SubscribeOn<Ob>
    
    let parent: Parent
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    // 这个 Sink, 主要的作用, 是在 Subscribe 的时候, 执行特殊的逻辑.
    // 所以他的 On 其实就是完全的 Forward. 没有特殊的逻辑.
    func on(_ event: Event<Element>) {
        self.forwardOn(event)
        
        if event.isStopEvent {
            self.dispose()
        }
    }
    
    /*
     如果一个 Sink 有 run 方法, 那么就是这个 Sink, 在 Subscribe 的时候, 有着特殊的设计.
     SubscribeOn 的特殊设计就是. 将 source subscribe 这件事, 经过 scheduler 进行调度.
     */
    func run() -> Disposable {
        let disposeEverything = SerialDisposable()
        let cancelSchedule = SingleAssignmentDisposable()
        disposeEverything.disposable = cancelSchedule
        
        // 在这里没有明白, cancelSchedule 这个对象的意义在哪里.
        let disposeSchedule = self.parent.scheduler.schedule(()) { _ -> Disposable in
            let subscription = self.parent.source.subscribe(self)
            disposeEverything.disposable = ScheduledDisposable(scheduler: self.parent.scheduler,
                                                               disposable: subscription)
            return Disposables.create()
        }
        cancelSchedule.setDisposable(disposeSchedule)
        
        return disposeEverything
    }
}

// 还是, 真正产生的是一个 Producer 对象, 会在监听真正发生的时候, 发挥作用.
final private class SubscribeOn<Ob: ObservableType>: Producer<Ob.Element> {
    let source: Ob
    let scheduler: ImmediateSchedulerType
    
    init(source: Ob, scheduler: ImmediateSchedulerType) {
        self.source = source
        self.scheduler = scheduler
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Ob.Element {
        let sink = SubscribeOnSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}
