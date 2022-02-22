//
//  BehaviorSubject.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 5/23/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a value that changes over time.
///
/// Observers can subscribe to the subject to receive the last (or initial) value and all subsequent notifications.
public final class BehaviorSubject<Element>
: Observable<Element>
, SubjectType
, ObserverType
, SynchronizedUnsubscribeType
, Cancelable {
    
    public typealias SubjectObserverType = BehaviorSubject<Element>
    
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType
    
    /// Indicates whether the subject has any observers
    public var hasObservers: Bool {
        self.lock.performLocked { self.observers.count > 0 }
    }
    
    let lock = RecursiveLock()
    
    // state
    private var disposed = false
    // 这个类存在的意义就在于此, 它保存了一个值在内部. 作为 Publisher, 他要将存储的这个值, 以及这个值的变化, 发送给自己存储的所有观察者
    private var element: Element
    private var observers = Observers()
    private var stoppedEvent: Event<Element>?
    
#if DEBUG
    private let synchronizationTracker = SynchronizationTracker()
#endif
    
    /// Indicates whether the subject has been disposed.
    /// 这是为了完成 Cancleable 协议.
    public var isDisposed: Bool {
        self.disposed
    }
    
    /// Initializes a new instance of the subject that caches its last value and starts with the specified value.
    ///
    // 必须在生成 PublishSubject 的时候, 必须要存储初值.
    public init(value: Element) {
        // 具有一个默认的参数值.
        self.element = value
        
#if TRACE_RESOURCES
        _ = Resources.incrementTotal()
#endif
    }
    
    /// Gets the current value or throws an error.
    ///
    /// - returns: Latest value.
    public func value() throws -> Element {
        self.lock.lock(); defer { self.lock.unlock() }
        
        // 在框架层, 经常写 throws 相关的实现. 自己的代码里面, 很少写. 这是自己的思维不太够.
        if self.isDisposed {
            throw RxError.disposed(object: self)
        }
        
        // 如果 stop event 是 error 类型的, 直接抛出错误.
        if let error = self.stoppedEvent?.error {
            // intentionally throw exception
            throw error
        }
        else {
            return self.element
        }
    }
    
    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>) {
        // 真正的触发函数, 还是在 dispatch 的内部.
        dispatch(self.synchronized_on(event), event)
    }
    
    // 一个挺不好的实现, 这里的函数, 应该叫做, synchronize_get_observers.
    // 就是根据当前的状态, 返回应该接受到 event 的所有观察者们.
    func synchronized_on(_ event: Event<Element>) -> Observers {
        self.lock.lock(); defer { self.lock.unlock() }
        if self.stoppedEvent != nil || self.isDisposed {
            return Observers()
        }
        
        switch event {
        case .next(let element):
            // 一个挺不好的实现, 在 get 方法里面, 插入了副作用.
            // 记录 element, 和 stopevent 的方法, 应该和获取观察者的代码逻辑分开.
            self.element = element
        case .error, .completed:
            self.stoppedEvent = event
        }
        
        return self.observers
    }
    
    /// Subscribes an observer to the subject.
    ///
    /// - parameter observer: Observer to subscribe to the subject.
    /// - returns: Disposable object that can be used to unsubscribe the observer from the subject.
    public override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked { self.synchronized_subscribe(observer) }
    }
    
    // 很好的命名方式, synchronize 开头, 就预示着, 方法内部是在线程安全的环境下执行的.
    // 在调用方法时, 外部函数已经确保了环境可靠, 内部函数, 也就不需要做这方面的考虑.
    // 这种, 明确的进行验证, 然后保证之后的逻辑, 处于可靠的状态, 是写好代码很好的技巧.
    func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        if self.isDisposed {
            // 如果, 自己已经 disposed 了, 那么直接给新监听者发送一个自定义的 error.
            // 然后返回一个 fakeDispose
            // 主动地发送一个 error, 监听者应该在自身内部, 做资源的 free 操作. 所以, 返回的 subscription, 应该什么都不做.
            observer.on(.error(RxError.disposed(object: self)))
            return Disposables.create()
        }
        
        if let stoppedEvent = self.stoppedEvent {
            // 这个类的含义, 就是缓存上一个 event. 所以, 如果自己已经 stop 了, 应该把这个 event 发送给新的监听者.
            observer.on(stoppedEvent)
            return Disposables.create()
        }
        
        // 保存新的 Observer.
        let key = self.observers.insert(observer.on)
        // 每个新的 Observer, 接受缓存的 element 的值.
        observer.on(.next(self.element))
        
        return SubscriptionDisposable(owner: self, key: key)
    }
    
    
    /*
     取消某个监听者注册的逻辑.
     
     一定要搞清, subscribe 返回的东西的意义. 对于 Subject 来说, 就是将 Observer 从自己的 obserser 列表中剔除.
     之前的链条的终点是 Subject,
     Subject 又能发出新的信号给后方.
     
     之前链条的终点, 返回的 subscription, 掌管着之前链条节点的 dispose 相关的操作, subject 的 subscribe 返回的对象, 只对 subject 相关的逻辑负责.
     */
    func synchronizedUnsubscribe(_ disposeKey: DisposeKey) {
        self.lock.performLocked { self.synchronized_unsubscribe(disposeKey) }
    }
    
    func synchronized_unsubscribe(_ disposeKey: DisposeKey) {
        if self.isDisposed {
            return
        }
        _ = self.observers.removeKey(disposeKey)
    }
    
    /// Returns observer interface for subject.
    public func asObserver() -> BehaviorSubject<Element> {
        self
    }
    
    /// Unsubscribe all observers and release resources.
    /*
     明确的 dispose, 和接收到 stopevent 是不一样的.
     这个类的含义, 就是保存最后一个 event, 所以当 stop 了之后, 新的 Observer 应该有机会来接收到这个 stopEvent.
     但是 dispose 了之后, 就不应该在调用这个对象了.
     */
    public func dispose() {
        self.lock.performLocked {
            self.disposed = true
            self.observers.removeAll()
            self.stoppedEvent = nil
        }
    }
    
#if TRACE_RESOURCES
    deinit {
        _ = Resources.decrementTotal()
    }
#endif
}
