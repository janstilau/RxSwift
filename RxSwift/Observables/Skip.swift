//
//  Skip.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    
    public func skip(_ count: Int)
    -> Observable<Element> {
        SkipCount(source: self.asObservable(), count: count)
    }
}

extension ObservableType {
    
    public func skip(_ duration: RxTimeInterval, scheduler: SchedulerType)
    -> Observable<Element> {
        SkipTime(source: self.asObservable(), duration: duration, scheduler: scheduler)
    }
}

// count version

final private class SkipCountSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    
    typealias Element = Observer.Element
    typealias Parent = SkipCount<Element>
    
    let parent: Parent
    
    var remaining: Int
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        self.remaining = parent.count
        super.init(observer: observer, cancel: cancel)
    }
    
    // Skip 的含义就是, 前面几个事件过滤掉.
    // 所谓的过滤, 就是 SkipSink 之后的节点, 不会收到这个信号.
    // 这个逻辑, 就是在 SkipSink 中, 进行计数管理, 如果没到数量, 不进行 forward.
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            
            if self.remaining <= 0 {
                self.forwardOn(.next(value))
            } else {
                self.remaining -= 1
            }
        case .error:
            self.forwardOn(event)
            self.dispose()
        case .completed:
            self.forwardOn(event)
            self.dispose()
        }
    }
    
}

final private class SkipCount<Element>: Producer<Element> {
    let source: Observable<Element>
    let count: Int
    
    init(source: Observable<Element>, count: Int) {
        self.source = source
        self.count = count
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = SkipCountSink(parent: self, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        
        return (sink: sink, subscription: subscription)
    }
}

// time version

final private class SkipTimeSink<Element, Observer: ObserverType>: Sink<Observer>, ObserverType where Observer.Element == Element {
    typealias Parent = SkipTime<Element>
    
    let parent: Parent
    
    // state
    var open = false
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    // 当新的信号发送过来的时候, 如果自己状态不对, 就不处理.
    // 这个状态, 是在特定时间之后才会触发.
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            if self.open {
                self.forwardOn(.next(value))
            }
        case .error:
            self.forwardOn(event)
            self.dispose()
        case .completed:
            self.forwardOn(event)
            self.dispose()
        }
    }
    
    func tick() {
        self.open = true
    }
    
    
    // 对于 SkipTime 来说, 它除了取消 parent.source.subscribe 订阅外, 还需要取消定时器.
    func run() -> Disposable {
        let disposeTimer = self.parent.scheduler.scheduleRelative((), dueTime: self.parent.duration) { _ in
            self.tick()
            return Disposables.create()
        }
        
        let disposeSubscription = self.parent.source.subscribe(self)
        return Disposables.create(disposeTimer, disposeSubscription)
    }
}

final private class SkipTime<Element>: Producer<Element> {
    let source: Observable<Element>
    let duration: RxTimeInterval
    let scheduler: SchedulerType
    
    init(source: Observable<Element>, duration: RxTimeInterval, scheduler: SchedulerType) {
        self.source = source
        self.scheduler = scheduler
        self.duration = duration
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = SkipTimeSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}
