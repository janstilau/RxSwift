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
    
    /*
     SubscribeOnSink 在 On 方法里面, 没有任何的特殊设计. 就是传统的 forward.
     */
    func on(_ event: Event<Element>) {
        self.forwardOn(event)
        
        if event.isStopEvent {
            self.dispose()
        }
    }
    
    func run() -> Disposable {
        let disposeEverything = SerialDisposable()
        let cancelSchedule = SingleAssignmentDisposable()
        
        disposeEverything.disposable = cancelSchedule
        
        // 在 特定的 scheduler 进行 subscribe 的动作.
        
        // 相应链条还是完整的保留了下来, 自己的这个节点, 在真正的相应链条里面, 就是纯粹的中间中介.
        // 之所以有自己的这一环节, 仅仅是在创建这样一个链条的时候, 要将创建这一过程, 通过 scheduler 进行调度. 
        let disposeSchedule = self.parent.scheduler.schedule(()) { _ -> Disposable in
            let subscription = self.parent.source.subscribe(self)
            disposeEverything.disposable = ScheduledDisposable(scheduler: self.parent.scheduler, disposable: subscription)
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
