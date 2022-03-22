

extension ObservableType {
    // 过滤之前的数据. 按照次数来.
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
    // 这个逻辑, 封装到了 SkipSink 的内部. 就是有一个计数器, 只有到达了固定的数量之后, 才会继续 forward 给后面的 Observer 发送数据.
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            if self.remaining <= 0 {
                // 只有到达了计数之后, 才向后进行数据的传递.
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
    
    // 生成一个 SkipSink 的节点. 数据的流转, 先要在这个节点中处理, 然后传递到后面的节点.
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        // Observer 是自己的后续节点, 在自己处理完逻辑之后, 将数据传递给后面的 observer 对象.
        let sink = SkipCountSink(parent: self, observer: observer, cancel: cancel)
        // 将 Sink 当做 source 的下游节点,
        // source --> sink --> observer
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
            // 只有在 self.open 的时候, 才会将状态发送给后方的节点. 
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
            // 在, 某些时间过去之后, 触发 tick 的操作. 这个 tick 就是进行状态的改变.
            // 仅仅在 on 的时候, 发挥作用.
            self.tick()
            return Disposables.create()
        }
        // 在这里, 还是有 source.subscribe 的机制.
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
