//
//  ObserveOn.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 7/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    
    public func observe(on scheduler: ImmediateSchedulerType)
    -> Observable<Element> {
        guard let serialScheduler = scheduler as? SerialDispatchQueueScheduler else {
            return ObserveOn(source: self.asObservable(), scheduler: scheduler)
        }
        return ObserveOnSerialDispatchQueue(source: self.asObservable(),
                                            scheduler: serialScheduler)
    }
    
    @available(*, deprecated, renamed: "observe(on:)")
    public func observeOn(_ scheduler: ImmediateSchedulerType)
    -> Observable<Element> {
        observe(on: scheduler)
    }
}

final private class ObserveOn<Element>: Producer<Element> {
    
    let scheduler: ImmediateSchedulerType
    let source: Observable<Element>
    
    init(source: Observable<Element>, scheduler: ImmediateSchedulerType) {
        self.scheduler = scheduler
        self.source = source
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = ObserveOnSink(scheduler: self.scheduler, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}

enum ObserveOnState : Int32 {
    // pump is not running
    case stopped = 0
    // pump is running
    case running = 1
}

final private class ObserveOnSink<Observer: ObserverType>: ObserverBase<Observer.Element> {
    typealias Element = Observer.Element
    
    let scheduler: ImmediateSchedulerType
    
    var lock = SpinLock()
    let observer: Observer
    
    // state
    var state = ObserveOnState.stopped
    var queue = Queue<Event<Element>>(capacity: 10)
    
    let scheduleDisposable = SerialDisposable()
    let cancel: Cancelable
    
    init(scheduler: ImmediateSchedulerType, observer: Observer, cancel: Cancelable) {
        self.scheduler = scheduler
        self.observer = observer
        self.cancel = cancel
    }
    
    override func onCore(_ event: Event<Element>) {
        let shouldStart = self.lock.performLocked { () -> Bool in
            self.queue.enqueue(event)
            
            switch self.state {
            case .stopped:
                self.state = .running
                return true
            case .running:
                return false
            }
        }
        
        if shouldStart {
            self.scheduleDisposable.disposable = self.scheduler.scheduleRecursive((), action: self.run)
        }
    }
    
    func run(_ state: (), _ recurse: (()) -> Void) {
        let (nextEvent, observer) = self.lock.performLocked { () -> (Event<Element>?, Observer) in
            if !self.queue.isEmpty {
                return (self.queue.dequeue(), self.observer)
            }
            else {
                self.state = .stopped
                return (nil, self.observer)
            }
        }
        
        if let nextEvent = nextEvent, !self.cancel.isDisposed {
            observer.on(nextEvent)
            if nextEvent.isStopEvent {
                self.dispose()
            }
        }
        else {
            return
        }
        
        let shouldContinue = self.shouldContinue_synchronized()
        
        if shouldContinue {
            recurse(())
        }
    }
    
    func shouldContinue_synchronized() -> Bool {
        self.lock.performLocked {
            let isEmpty = self.queue.isEmpty
            if isEmpty { self.state = .stopped }
            return !isEmpty
        }
    }
    
    override func dispose() {
        super.dispose()
        
        self.cancel.dispose()
        self.scheduleDisposable.dispose()
    }
}

#if TRACE_RESOURCES
private let numberOfSerialDispatchObservables = AtomicInt(0)
extension Resources {
    /**
     Counts number of `SerialDispatchQueueObservables`.
     
     Purposed for unit tests.
     */
    public static var numberOfSerialDispatchQueueObservables: Int32 {
        return load(numberOfSerialDispatchObservables)
    }
}
#endif

/*
 
 */
final private class ObserveOnSerialDispatchQueueSink<Observer: ObserverType>: ObserverBase<Observer.Element> {
    
    let scheduler: SerialDispatchQueueScheduler
    let observer: Observer
    
    let cancel: Cancelable
    
    // 在定义成员变量的时候, 编写 Tuple 的 name, 可以直接在定义的时候使用.
    var cachedScheduleLambda: (((sink: ObserveOnSerialDispatchQueueSink<Observer>, event: Event<Element>)) -> Disposable)!
    
    init(scheduler: SerialDispatchQueueScheduler, observer: Observer, cancel: Cancelable) {
        self.scheduler = scheduler
        self.observer = observer
        self.cancel = cancel
        super.init()
        
        self.cachedScheduleLambda = { pair in
            guard !cancel.isDisposed else { return Disposables.create() }
            
            // 传递 event 的过程.
            pair.sink.observer.on(pair.event)
            
            if pair.event.isStopEvent {
                pair.sink.dispose()
            }
            
            return Disposables.create()
        }
    }
    
    override func onCore(_ event: Event<Element>) {
        // 调度的过程.
        _ = self.scheduler.schedule((self, event), action: self.cachedScheduleLambda!)
    }
    
    override func dispose() {
        super.dispose()
        
        self.cancel.dispose()
    }
}

final private class ObserveOnSerialDispatchQueue<Element>: Producer<Element> {
    let scheduler: SerialDispatchQueueScheduler
    let source: Observable<Element>
    
    init(source: Observable<Element>, scheduler: SerialDispatchQueueScheduler) {
        self.scheduler = scheduler
        self.source = source
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        /*
         source subscribe ObserveOnSerialDispatchQueueSink
         ObserveOnSerialDispatchQueueSink 内部, 会将信号中的数据处理, 进行调度.
         然后在调度后的代码块里面, 是将数据 forward 到自己存储的 Observer 上.
         这样, 数据处理就从原来的线程, 或者时间点, 到了新的线程或者时间了.
         */
        let sink = ObserveOnSerialDispatchQueueSink(scheduler: self.scheduler, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
