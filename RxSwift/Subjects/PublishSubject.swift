/*
 Subject 是一个交接点, 可以将原有的指令世界的逻辑, 通过 Subject 转移到响应式的世界.
 一般来说, 这个 Subject 会是一个成员变量, 业务类完成自己的操作只有, 会修改这个成员变量. Subject 的成员变量的修改, 会触发信号的发送.
 这样, 任何监听这个成员变量的地方, 就可以触发之前注册的各种业务逻辑了.
 */
public final class PublishSubject<Element> :
Observable<Element>
, SubjectType
, Cancelable
, ObserverType
, SynchronizedUnsubscribeType {
    
    public typealias SubjectObserverType = PublishSubject<Element>
    
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType
    
    private let lock = RecursiveLock()
    
    // state
    private var disposed = false // 标记, 是否已经结束.
    private var observers = Observers() // 存储, 所有的后续监听者.
    private var stopped = false // 存储停止事件, 这样, 当新的监听者到来的时候, 如果已经停止, 会接收到停止信息.
    private var stoppedEvent = nil as Event<Element>? // 存储停止事件, 这样, 当新的监听者到来的时候, 如果已经停止, 会接收到停止信息.
    
    /// Indicates whether the subject has been isDisposed.
    public var isDisposed: Bool {
        self.disposed
    }
    
    /// Indicates whether the subject has any observers
    public var hasObservers: Bool {
        self.lock.performLocked { self.observers.count > 0 }
    }
    
    /// Creates a subject.
    public override init() {
        super.init()
    }
    
    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>) {
        dispatch(self.synchronized_on(event), event)
    }

    // 一个 Get 函数里面, 有这么大的副作用, 不明白为什么要这样的设计.
    func synchronized_on(_ event: Event<Element>) -> Observers {
        self.lock.lock(); defer { self.lock.unlock() }
        
        switch event {
        case .next:
            if self.isDisposed || self.stopped {
                return Observers()
            }
            return self.observers
        case .completed, .error:
            // 如果, 是结束事件, 那么要记录一下 stopEvent.
            // 在之后的订阅的时候, 直接传递 stopEvent 给对方.
            if self.stoppedEvent == nil {
                self.stoppedEvent = event
                self.stopped = true
                let observers = self.observers
                self.observers.removeAll()
                return observers
            }
            
            return Observers()
        }
    }
    
    /**
     Subscribes an observer to the subject.
     
     - parameter observer: Observer to subscribe to the subject.
     - returns: Disposable object that can be used to unsubscribe the observer from the subject.
     */
    public override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked { self.synchronized_subscribe(observer) }
    }
    
    // synchronized_subscribe 这种明显函数名的命名, 展示了这个方法, 就是在锁的环境下. 方法内部不需要考虑所的问题.
    func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable
    where Observer.Element == Element {
        // 如果, 已经 Stopped 了, 那么新的监听者, 会监听到之前存储的 StoppedEvent.
        if let stoppedEvent = self.stoppedEvent {
            observer.on(stoppedEvent)
            return Disposables.create()
        }
        
        // 如果, 已经 isDisposed 了, 那么不应该在注册新的监听者.
        if self.isDisposed {
            observer.on(.error(RxError.disposed(object: self)))
            return Disposables.create()
        }
        
        // 在 Share 里面, 使用了 Subject. 因为 Subject 这种存储, 是真正的分发的结构. 所有的后继节点, 公用一个源头.
        // 这种, 直接存储对象的方法的方式, 是会保留对象的生命周期的. 
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
    // asObserver() 的限制, 是返回一个 Observeable 就可以了. 所以, 具体各个子类型, 返回什么样的数据, 各个子类型自己把握.
    public func asObserver() -> PublishSubject<Element> {
        self
    }
    
    /// Unsubscribe all observers and release resources.
    public func dispose() {
        self.lock.performLocked { self.synchronized_dispose() }
    }

    // Subject 的dispose, 会把下个节点删除.
    // 所以 Subject 的 Dispose 会引起内存的变化.
    final func synchronized_dispose() {
        self.disposed = true
        self.observers.removeAll()
        self.stoppedEvent = nil
    }
}
