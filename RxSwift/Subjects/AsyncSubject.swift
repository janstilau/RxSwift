/// An AsyncSubject emits the last value (and only the last value) emitted by the source Observable,
/// and only after that source Observable completes.
///
/// (If the source Observable does not emit any values, the AsyncSubject also completes without emitting any values.)

//

public final class AsyncSubject<Element>
: Observable<Element>
, SubjectType
, ObserverType
, SynchronizedUnsubscribeType {
    
    public typealias SubjectObserverType = AsyncSubject<Element>
    
    // Observers 是一个 Bag 对象
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType
    
    /// Indicates whether the subject has any observers
    public var hasObservers: Bool {
        self.lock.performLocked {
            self.observers.count > 0
        }
    }
    
    let lock = RecursiveLock()
    
    // state
    private var observers = Observers()
    private var isStopped = false
    private var stoppedEvent = nil as Event<Element>? {
        didSet {
            // isStopped 的状态, 根据 stoppedEvent 的 set 来改变.
            self.isStopped = self.stoppedEvent != nil
        }
    }
    private var lastElement: Element?
    
    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    
    /*
     在这个类的 on 里面, 进行了监听. 如果有 element 的值, 就进行更新, 然后在 complete 的时候, 进行一次最后的 element 的发送, 一次 complete 的发送.
     否则, 就只有一次 compelte, 或者 error 的发送.
     一定要记住, 主动的进行相关 stopEvent 的发送, 是非常重要的 .
     */
    public func on(_ event: Event<Element>) {
        let (observers, event) = self.synchronized_on(event)
        switch event {
            // 只有, 当 event 是 Complete 的时候, 才会出现 next. 其实比较混乱, 感觉直接在 On 把逻辑写完更好.
        case .next:
            dispatch(observers, event)
            dispatch(observers, .completed)
        case .completed:
            dispatch(observers, event)
        case .error:
            dispatch(observers, event)
        }
    }
    
    // synchronized_on 的逻辑有点混乱. 其实这是一个 Get 函数.
    func synchronized_on(_ event: Event<Element>) -> (Observers, Event<Element>) {
        self.lock.lock(); defer { self.lock.unlock() }
        
        if self.isStopped {
            return (Observers(), .completed)
        }
        
        switch event {
        case .next(let element):
            // 原本的 Next 事件, 返回一个空 Bag, 所以是空操作.
            self.lastElement = element
            return (Observers(), .completed)
        case .error:
            // 如果是 error 事件, 返回所有的 Observers, 触发 error.
            self.stoppedEvent = event
            let observers = self.observers
            self.observers.removeAll()
            return (observers, event)
        case .completed:
            // 在 Complete 事件里面, 会把所有的 Observers 删除, 然后传递到外面进行后续逻辑.
            // 在 on 里面, 会进行最后一个 ele 的发送, 然后发送 compelte.
            let observers = self.observers
            self.observers.removeAll()
            
            if let lastElement = self.lastElement {
                self.stoppedEvent = .next(lastElement)
                return (observers, .next(lastElement))
            } else {
                self.stoppedEvent = event
                return (observers, .completed)
            }
        }
    }
    
    /// Subscribes an observer to the subject.
    ///
    /// - parameter observer: Observer to subscribe to the subject.
    /// - returns: Disposable object that can be used to unsubscribe the observer from the subject.
    public override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked { self.synchronized_subscribe(observer) }
    }
    
    func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        if let stoppedEvent = self.stoppedEvent {
            switch stoppedEvent {
            case .next:
                observer.on(stoppedEvent)
                observer.on(.completed)
            case .completed:
                observer.on(stoppedEvent)
            case .error:
                observer.on(stoppedEvent)
            }
            return Disposables.create()
        }
        
        let key = self.observers.insert(observer.on)
        
        return SubscriptionDisposable(owner: self, key: key)
    }
    
    func synchronizedUnsubscribe(_ disposeKey: DisposeKey) {
        self.lock.performLocked { self.synchronized_unsubscribe(disposeKey) }
    }
    
    func synchronized_unsubscribe(_ disposeKey: DisposeKey) {
        _ = self.observers.removeKey(disposeKey)
    }
    
    /// Returns observer interface for subject.
    public func asObserver() -> AsyncSubject<Element> {
        self
    }
}

