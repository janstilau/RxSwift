//
//  ShareReplayScope.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 5/28/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//


public enum SubjectLifetimeScope {
    /*
     **Each connection will have it's own subject instance to store replay events.**
     **Connections will be isolated from each another.**
     
     Configures the underlying implementation to behave equivalent to.
     
     ```
     source.multicast(makeSubject: { MySubject() }).refCount()
     ```
     
     **This is the recommended default.**
     
     This has the following consequences:
     * `retry` or `concat` operators will function as expected because terminating the sequence will clear internal state.
     * Each connection to source observable sequence will use it's own subject.
     * When the number of subscribers drops from 1 to 0 and connection to source sequence is disposed, subject will be cleared.
     
     
     ```
     let xs = Observable.deferred { () -> Observable<TimeInterval> in
     print("Performing work ...")
     return Observable.just(Date().timeIntervalSince1970)
     }
     .share(replay: 1, scope: .whileConnected)
     
     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     
     ```
     
     Notice how time interval is different and `Performing work ...` is printed each time)
     
     ```
     Performing work ...
     next 1495998900.82141
     completed
     
     Performing work ...
     next 1495998900.82359
     completed
     
     Performing work ...
     next 1495998900.82444
     completed
     
     
     ```
     
     */
    case whileConnected
    
    /*
     **One subject will store replay events for all connections to source.**
     **Connections won't be isolated from each another.**
     
     Configures the underlying implementation behave equivalent to.
     
     ```
     source.multicast(MySubject()).refCount()
     ```
     
     This has the following consequences:
     * Using `retry` or `concat` operators after this operator usually isn't advised.
     * Each connection to source observable sequence will share the same subject.
     * After number of subscribers drops from 1 to 0 and connection to source observable sequence is dispose, this operator will
     continue holding a reference to the same subject.
     If at some later moment a new observer initiates a new connection to source it can potentially receive
     some of the stale events received during previous connection.
     * After source sequence terminates any new observer will always immediately receive replayed elements and terminal event.
     No new subscriptions to source observable sequence will be attempted.
     
     ```
     let xs = Observable.deferred { () -> Observable<TimeInterval> in
     print("Performing work ...")
     return Observable.just(Date().timeIntervalSince1970)
     }
     .share(replay: 1, scope: .forever)
     
     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     ```
     
     Notice how time interval is the same, replayed, and `Performing work ...` is printed only once
     
     ```
     Performing work ...
     next 1495999013.76356
     completed
     
     next 1495999013.76356
     completed
     
     next 1495999013.76356
     completed
     ```
     
     */
    case forever
}

/*
 对于 Publisher 来说, 每一次 subscribe, 默认其实都会创建一条序列链条.
 如何重用上游的事件序列呢, 就是要找一个节点, 将所有的下游进行存储.
 share 所做的, 就是这个收集存储的工作.
 
 而 Subject, 则是天然有着这层存储属性的.
 */
extension ObservableType {
    
    /*
     Returns an observable sequence that **shares a single subscription to the underlying sequence**, and immediately upon subscription replays  elements in buffer.
     
     This operator is equivalent to:
     * `.whileConnected`
     ```
     // Each connection will have it's own subject instance to store replay events.
     // Connections will be isolated from each another.
     source.multicast(makeSubject: { Replay.create(bufferSize: replay) }).refCount()
     ```
     * `.forever`
     ```
     // One subject will store replay events for all connections to source.
     // Connections won't be isolated from each another.
     source.multicast(Replay.create(bufferSize: replay)).refCount()
     ```
     
     It uses optimized versions of the operators for most common operations.
     */
    public func share(replay: Int = 0, scope: SubjectLifetimeScope = .whileConnected)
    -> Observable<Element> {
        switch scope {
        case .forever:
            switch replay {
            case 0: return self.multicast(PublishSubject()).refCount()
            default: return self.multicast(ReplaySubject.create(bufferSize: replay)).refCount()
            }
            
        case .whileConnected:
            switch replay {
            case 0: return ShareWhileConnected(source: self.asObservable())
            case 1: return ShareReplay1WhileConnected(source: self.asObservable())
            default: return self.multicast(makeSubject: { ReplaySubject.create(bufferSize: replay) }).refCount()
            }
        }
    }
}

private final class ShareReplay1WhileConnectedConnection<Element>
: ObserverType
, SynchronizedUnsubscribeType {
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType
    
    typealias Parent = ShareReplay1WhileConnected<Element>
    private let parent: Parent
    private let subscription = SingleAssignmentDisposable()
    
    private let lock: RecursiveLock
    private var disposed: Bool = false
    fileprivate var observers = Observers()
    
    // 和下面的唯一区别, 就是这里存了一个 Ele 到内部, 当有新的下游节点的时候, 可以直接使用存储的值.
    private var element: Element?
    
    init(parent: Parent, lock: RecursiveLock) {
        self.parent = parent
        self.lock = lock
    }
    
    final func on(_ event: Event<Element>) {
        let observers = self.lock.performLocked { self.synchronized_on(event) }
        dispatch(observers, event)
    }
    
    final private func synchronized_on(_ event: Event<Element>) -> Observers {
        if self.disposed {
            return Observers()
        }
        
        switch event {
        case .next(let element):
            self.element = element
            return self.observers
        case .error, .completed:
            let observers = self.observers
            self.synchronized_dispose()
            return observers
        }
    }
    
    final func connect() {
        self.subscription.setDisposable(self.parent.source.subscribe(self))
    }
    
    final func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked {
            // 如果, 已经存储了值, 就在下一个 Observer 进行注册的时候, 传递该值.
            if let element = self.element {
                observer.on(.next(element))
            }
            let disposeKey = self.observers.insert(observer.on)
            return SubscriptionDisposable(owner: self, key: disposeKey)
        }
    }
    
    final private func synchronized_dispose() {
        self.disposed = true
        if self.parent.connection === self {
            self.parent.connection = nil
        }
        self.observers = Observers()
    }
    
    final func synchronizedUnsubscribe(_ disposeKey: DisposeKey) {
        if self.lock.performLocked({ self.synchronized_unsubscribe(disposeKey) }) {
            self.subscription.dispose()
        }
    }
    
    final private func synchronized_unsubscribe(_ disposeKey: DisposeKey) -> Bool {
        if self.observers.removeKey(disposeKey) == nil {
            return false
        }
        
        if self.observers.count == 0 {
            self.synchronized_dispose()
            return true
        }
        
        return false
    }
}

// optimized version of share replay for most common case
final private class ShareReplay1WhileConnected<Element>
: Observable<Element> {
    
    fileprivate typealias Connection = ShareReplay1WhileConnectedConnection<Element>
    
    fileprivate let source: Observable<Element>
    
    private let lock = RecursiveLock()
    
    fileprivate var connection: Connection?
    
    init(source: Observable<Element>) {
        self.source = source
    }
    
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.lock()
        let connection = self.synchronized_subscribe(observer)
        let count = connection.observers.count
        
        let disposable = connection.synchronized_subscribe(observer)
        self.lock.unlock()
        
        if count == 0 {
            connection.connect()
        }
        
        return disposable
    }
    
    private func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Connection where Observer.Element == Element {
        let connection: Connection
        
        if let existingConnection = self.connection {
            connection = existingConnection
        } else {
            connection = ShareReplay1WhileConnectedConnection<Element>(
                parent: self,
                lock: self.lock)
            self.connection = connection
        }
        
        return connection
    }
}

// SynchronizedUnsubscribeType 的出现, 就暗示了, 在这个类的内部, 进行了后续监听者的管理.
private final class ShareWhileConnectedConnection<Element>
: ObserverType, SynchronizedUnsubscribeType {
    
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType
    typealias Parent = ShareWhileConnected<Element>
    
    private let parent: Parent // 这种, 被使用类和使用类相互引用在 rx 里面很常用.
    private let subscription = SingleAssignmentDisposable()
    
    private let lock: RecursiveLock
    private var disposed: Bool = false
    /*
     这里和 Subject 是一样的, 将 Observers 存储到了自己的内部.
     */
    fileprivate var observers = Observers()
    
    init(parent: Parent, lock: RecursiveLock) {
        self.parent = parent
        self.lock = lock
    }
    
    // ShareWhileConnected 充当了自己的上游, 在自己的 On 里面, 将所有的事件, 交给自己记录的所有的 observers 进行处理.
    final func on(_ event: Event<Element>) {
        let observers = self.lock.performLocked { self.synchronized_on(event) }
        dispatch(observers, event)
    }
    
    final private func synchronized_on(_ event: Event<Element>) -> Observers {
        if self.disposed {
            return Observers()
        }
        
        switch event {
        case .next:
            return self.observers
        case .error, .completed:
            let observers = self.observers
            self.synchronized_dispose()
            return observers
        }
    }
    
    final func connect() {
        // 将 source 和 自己进行相连. 这样, source 的信号, 直接到自己内部, 自己再次分发给所记录的所有下游节点.
        self.subscription.setDisposable(self.parent.source.subscribe(self))
    }
    
    final func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.performLocked {
            let disposeKey = self.observers.insert(observer.on)
            return SubscriptionDisposable(owner: self, key: disposeKey)
        }
    }
    
    final private func synchronized_dispose() {
        self.disposed = true
        if self.parent.connection === self {
            self.parent.connection = nil
        }
        self.observers = Observers()
    }
    
    final func synchronizedUnsubscribe(_ disposeKey: DisposeKey) {
        if self.lock.performLocked({ self.synchronized_unsubscribe(disposeKey) }) {
            // 如果没有了下游, 那么自己也就可以结束了.
            self.subscription.dispose()
        }
    }
    
    final private func synchronized_unsubscribe(_ disposeKey: DisposeKey) -> Bool {
        if self.observers.removeKey(disposeKey) == nil {
            return false
        }
        
        if self.observers.count == 0 {
            self.synchronized_dispose()
            return true
        }
        
        return false
    }
}

// optimized version of share replay for most common case
// 被 Shared 的, 还是一个 observable.
final private class ShareWhileConnected<Element> : Observable<Element> {
    
    fileprivate typealias Connection = ShareWhileConnectedConnection<Element>
    
    fileprivate let source: Observable<Element>
    
    private let lock = RecursiveLock()
    fileprivate var connection: Connection?
    
    init(source: Observable<Element>) {
        self.source = source
    }
    
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.lock.lock()
        
        // synchronized_subscribe 就是 createConnectionIfNeed.
        let connection = self.synchronized_subscribe(observer)
        let count = connection.observers.count
        
        /*
         将下游节点, 注册到了 ShareWhileConnectedConnection<Element> 的内部.
         */
        let disposable = connection.synchronized_subscribe(observer)
        self.lock.unlock()
        
        /*
         如果, 这是第一次进行注册, 那么将
         */
        if count == 0 {
            connection.connect()
        }
        
        return disposable
    }
    
    /*
     非常非常烂的命名方式, 使用 createConnectionIfNeed 不更好吗?
     */
    private func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) -> Connection where Observer.Element == Element {
        let connection: Connection
        
        if let existingConnection = self.connection {
            connection = existingConnection
        } else {
            connection = ShareWhileConnectedConnection<Element>( parent: self, lock: self.lock)
            self.connection = connection
        }
        
        return connection
    }
}
