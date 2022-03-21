

/*
 Subject 的意义在于, 这是一个从指令式编码模块, 到响应式编码模块的交接点.
 我们可以使用原有的指令式的代码, 来计算出值, 然后使用 Subject 进行信号的发射.
 而 Subject 的内部, 其实是保存了各个 Observers 的.
 */

/*
 真正的使用 rx 开发, 进行各种 Observable 的组装实在是过于复杂.
 对于想要信号槽的那种松耦合的开发场景, 使用 Subject 是一个非常通用的行为.
 在 App 架构那本书里面, 简化版的 MVVM 也是使用了 Subject 来当做源头.
 */
public final class PublishSubject<Element> : Observable<Element>
, SubjectType
, Cancelable
, ObserverType
, SynchronizedUnsubscribeType {
    
    public typealias SubjectObserverType = PublishSubject<Element>
    
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType
    
    /// Indicates whether the subject has any observers
    public var hasObservers: Bool {
        self.lock.performLocked { self.observers.count > 0 }
    }
    
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
    
    // 这是一个 Get 函数, 这里的命名不好.
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
        if let stoppedEvent = self.stoppedEvent {
            observer.on(stoppedEvent)
            return Disposables.create()
        }
        
        if self.isDisposed {
            observer.on(.error(RxError.disposed(object: self)))
            return Disposables.create()
        }
        
        // 在 Share 里面, 使用了 Subject. 因为 Subject 这种存储, 是真正的分发的结构. 所有的后继节点, 公用一个源头.
        // Bag 里面, 仅仅存储闭包, 而这个闭包, 其实是有生命周期管理的. 
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
    
    final func synchronized_dispose() {
        self.disposed = true
        self.observers.removeAll()
        self.stoppedEvent = nil
    }
}
