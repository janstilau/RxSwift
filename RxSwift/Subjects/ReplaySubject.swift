
// 大部分的逻辑, 和 PublishSubject 没有太大的区别.
// 有了缓存管理的相关的策略.
public class ReplaySubject<Element>
: Observable<Element>
, SubjectType
, ObserverType
, Disposable {
    
    public typealias SubjectObserverType = ReplaySubject<Element>
    
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType
    
    /// Indicates whether the subject has any observers
    public var hasObservers: Bool {
        self.lock.performLocked { self.observers.count > 0 }
    }
    
    fileprivate let lock = RecursiveLock()
    
    // state
    fileprivate var isDisposed = false
    fileprivate var stopped = false
    fileprivate var stoppedEvent = nil as Event<Element>? {
        didSet {
            self.stopped = self.stoppedEvent != nil
        }
    }
    fileprivate var observers = Observers()
    
    func unsubscribe(_ key: DisposeKey) {
        rxAbstractMethod()
    }
    
    final var isStopped: Bool {
        self.stopped
    }
    
    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>) {
        rxAbstractMethod()
    }
    
    /// Returns observer interface for subject.
    public func asObserver() -> ReplaySubject<Element> {
        self
    }
    
    /// Unsubscribe all observers and release resources.
    public func dispose() {
    }
    
    /// Creates new instance of `ReplaySubject` that replays at most `bufferSize` last elements of sequence.
    ///
    /// - parameter bufferSize: Maximal number of elements to replay to observer after subscription.
    /// - returns: New instance of replay subject.
    // 个人感觉, 这有点设计复杂, 直接数组不就得了, 一个的情况, 仅仅是 Many 的特例啊.
    public static func create(bufferSize: Int) -> ReplaySubject<Element> {
        if bufferSize == 1 {
            return ReplayOne()
        }
        else {
            return ReplayMany(bufferSize: bufferSize)
        }
    }
    
    /// Creates a new instance of `ReplaySubject` that buffers all the elements of a sequence.
    /// To avoid filling up memory, developer needs to make sure that the use case will only ever store a 'reasonable'
    /// number of elements.
    public static func createUnbounded() -> ReplaySubject<Element> {
        ReplayAll()
    }
}

private class ReplayBufferBase<Element>
: ReplaySubject<Element>
, SynchronizedUnsubscribeType {
    
    func trim() {
        rxAbstractMethod()
    }
    
    func addValueToBuffer(_ value: Element) {
        rxAbstractMethod()
    }
    
    func replayBuffer<Observer: ObserverType>(_ observer: Observer) where Observer.Element == Element {
        rxAbstractMethod()
    }
    
    override func on(_ event: Event<Element>) {
        dispatch(self.synchronized_on(event), event)
    }
    
    func synchronized_on(_ event: Event<Element>) -> Observers {
        self.lock.lock(); defer { self.lock.unlock() }
        if self.isDisposed {
            return Observers()
        }
        
        if self.isStopped {
            return Observers()
        }
        
        switch event {
        case .next(let element):
            self.addValueToBuffer(element)
            self.trim()
            return self.observers
        case .error, .completed:
            self.stoppedEvent = event
            self.trim()
            let observers = self.observers
            self.observers.removeAll()
            return observers
        }
    }
    
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked { self.synchronized_subscribe(observer) }
    }
    
    func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        if self.isDisposed {
            observer.on(.error(RxError.disposed(object: self)))
            return Disposables.create()
        }
        
        let anyObserver = observer.asObserver()
        
        self.replayBuffer(anyObserver)
        if let stoppedEvent = self.stoppedEvent {
            observer.on(stoppedEvent)
            return Disposables.create()
        }
        else {
            let key = self.observers.insert(observer.on)
            return SubscriptionDisposable(owner: self, key: key)
        }
    }
    
    func synchronizedUnsubscribe(_ disposeKey: DisposeKey) {
        self.lock.performLocked { self.synchronized_unsubscribe(disposeKey) }
    }
    
    func synchronized_unsubscribe(_ disposeKey: DisposeKey) {
        if self.isDisposed {
            return
        }
        
        _ = self.observers.removeKey(disposeKey)
    }
    
    override func dispose() {
        super.dispose()
        
        self.synchronizedDispose()
    }
    
    func synchronizedDispose() {
        self.lock.performLocked { self.synchronized_dispose() }
    }
    
    func synchronized_dispose() {
        self.isDisposed = true
        self.observers.removeAll()
    }
}

// 只存储一个值.
private final class ReplayOne<Element> : ReplayBufferBase<Element> {
    private var value: Element?
    
    override init() {
        super.init()
    }
    
    override func trim() {
        
    }
    
    // One, 就是替换.
    override func addValueToBuffer(_ value: Element) {
        self.value = value
    }
    
    override func replayBuffer<Observer: ObserverType>(_ observer: Observer) where Observer.Element == Element {
        if let value = self.value {
            observer.on(.next(value))
        }
    }
    
    override func synchronized_dispose() {
        super.synchronized_dispose()
        self.value = nil
    }
}

private class ReplayManyBase<Element>: ReplayBufferBase<Element> {
    fileprivate var queue: Queue<Element>
    
    init(queueSize: Int) {
        self.queue = Queue(capacity: queueSize + 1)
    }
    
    override func addValueToBuffer(_ value: Element) {
        self.queue.enqueue(value)
    }
    
    // 对于 Many 来说, 就是将已经缓存的数据, 给新添加的 Observer 逐个的进行发送. 
    override func replayBuffer<Observer: ObserverType>(_ observer: Observer) where Observer.Element == Element {
        for item in self.queue {
            observer.on(.next(item))
        }
    }
    
    override func synchronized_dispose() {
        super.synchronized_dispose()
        self.queue = Queue(capacity: 0)
    }
}

private final class ReplayMany<Element> : ReplayManyBase<Element> {
    private let bufferSize: Int
    
    init(bufferSize: Int) {
        self.bufferSize = bufferSize
        
        super.init(queueSize: bufferSize)
    }
    
    override func trim() {
        while self.queue.count > self.bufferSize {
            _ = self.queue.dequeue()
        }
    }
}

private final class ReplayAll<Element> : ReplayManyBase<Element> {
    init() {
        super.init(queueSize: 0)
    }
    
    // 从来不做 Trim 操作. 
    override func trim() {
        
    }
}
