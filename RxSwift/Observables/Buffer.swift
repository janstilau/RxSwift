
extension ObservableType {
    /*
     缓存数据, 到达了一定的量, 或者到达了一定的时间之后, 一次性将缓存的数据发送出去.
     */
    /*
     Projects each element of an observable sequence into a buffer that's sent out when either it's full or a given amount of time has elapsed, using the specified scheduler to run timers.
     
     A useful real-world analogy of this overload is the behavior of a ferry leaving the dock when all seats are taken, or at the scheduled time of departure, whichever event occurs first.
     */
    public func buffer(timeSpan: RxTimeInterval,
                       count: Int,
                       scheduler: SchedulerType)
    -> Observable<[Element]> {
        BufferTimeCount(source: self.asObservable(), timeSpan: timeSpan, count: count, scheduler: scheduler)
    }
}

/*
 为什么 Operator 可以简化开发. 那是因为各种逻辑, 其实是提前定义好多了, 在对应的 Operator 的 Sink 类里面.
 */
final private class BufferTimeCount<Element>: Producer<[Element]> {
    
    fileprivate let source: Observable<Element>
    
    fileprivate let scheduler: SchedulerType // 时间调度器.
    fileprivate let timeSpan: RxTimeInterval // 缓存的时间限制.
    
    fileprivate let count: Int //缓存的个数限制.
    
    
    init(source: Observable<Element>, timeSpan: RxTimeInterval, count: Int, scheduler: SchedulerType) {
        self.source = source
        self.timeSpan = timeSpan
        self.count = count
        self.scheduler = scheduler
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == [Element] {
        let sink = BufferTimeCountSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}

// 真正在响应链条的 Sink 值.
final private class BufferTimeCountSink<Element, Observer: ObserverType>
: Sink<Observer>
, LockOwnerType
, ObserverType
, SynchronizedOnType where Observer.Element == [Element] {
    
    typealias Parent = BufferTimeCount<Element>
    
    private let parent: Parent
    
    let lock = RecursiveLock()
    
    // state
    private let timerD = SerialDisposable()
    private var buffer = [Element]()
    private var windowID = 0
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    func run() -> Disposable {
        self.createTimer(self.windowID)
        // Source, 还是注册到 Self Sink 上.
        // 但是 cancle 的时候, 增加了对于时间调度的处理.
        return Disposables.create(timerD, parent.source.subscribe(self))
    }
    
    func startNewWindowAndSendCurrentOne() {
        // 根据 ID 来判断当前的 Version 环境.
        self.windowID = self.windowID &+ 1
        let windowID = self.windowID
        
        // 真正的 Next 信号的发出.
        let buffer = self.buffer
        self.buffer = []
        self.forwardOn(.next(buffer))
        
        // 再次启动定时器.
        self.createTimer(windowID)
    }
    
    func on(_ event: Event<Element>) {
        self.synchronizedOn(event)
    }
    
    // 在锁的环境下, 进行状态的累计
    func synchronized_on(_ event: Event<Element>) {
        switch event {
        case .next(let element):
            self.buffer.append(element)
            // 当触发了 Flush 条件只有, 进行数据的发送. 
            if self.buffer.count == self.parent.count {
                self.startNewWindowAndSendCurrentOne()
            }
            
        case .error(let error):
            self.buffer = []
            self.forwardOn(.error(error))
            self.dispose()
        case .completed:
            // 结束了, 要将已经缓存的数据, 进行 Flush 的操作.
            self.forwardOn(.next(self.buffer))
            self.forwardOn(.completed)
            self.dispose()
        }
    }
    
    
    // 建立, 定义清空的 Timer.
    func createTimer(_ windowID: Int) {
        if self.timerD.isDisposed {
            return
        }
        
        // 通过 count, 触发了 self.windowID 的修改.
        if self.windowID != windowID {
            return
        }
        
        let nextTimer = SingleAssignmentDisposable()
        
        self.timerD.disposable = nextTimer
        
        // windowID 会当做状态值, 在 scheduleRelative 的 Block 参数中使用.
        let disposable = self.parent.scheduler.scheduleRelative(windowID,
                                                                dueTime: self.parent.timeSpan) {
            previousWindowID in
            self.lock.performLocked {
                // 如果, windowID 改变了, 就是这个定时应该取消了.
                // 比如, count 达到了阈值, 那么伴随的 Timer 应该作废.
                if previousWindowID != self.windowID {
                    return
                }
                
                // 只要, 到时了, 就触发 Flush 的逻辑.
                self.startNewWindowAndSendCurrentOne()
            }
            // 当, 不需要返回一个有效的 Subscription 的时候, 就使用 Disposables.create 来满足编译器.
            return Disposables.create()
        }
        
        nextTimer.setDisposable(disposable)
    }
}
