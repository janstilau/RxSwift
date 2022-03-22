extension ObservableType {
    
    // 在 other 触发之前, 一直进行订阅.
    public func take<Source: ObservableType>(until other: Source)
    -> Observable<Element> {
        TakeUntil(source: self.asObservable(),
                  other: other.asObservable())
    }
    
    /*
     Returns elements from an observable sequence until the specified condition is true.
     */
    public func take(until predicate: @escaping (Element) throws -> Bool,
                     behavior: TakeBehavior = .exclusive)
    -> Observable<Element> {
        TakeUntilPredicate(source: self.asObservable(),
                           behavior: behavior,
                           predicate: predicate)
    }
    
    /*
     Returns elements from an observable sequence as long as a specified condition is true.
     */
    public func take(while predicate: @escaping (Element) throws -> Bool,
                     behavior: TakeBehavior = .exclusive)
    -> Observable<Element> {
        take(until: { try !predicate($0) }, behavior: behavior)
    }
}

/// Behaviors for the take operator family.
public enum TakeBehavior {
    /// Include the last element matching the predicate.
    case inclusive
    
    /// Exclude the last element matching the predicate.
    case exclusive
}

// MARK: - TakeUntil Observable
final private class TakeUntilSinkOther<Other, Observer: ObserverType>
: ObserverType
, LockOwnerType
, SynchronizedOnType {
    typealias Parent = TakeUntilSink<Other, Observer>
    typealias Element = Other
    
    private let parent: Parent
    
    var lock: RecursiveLock {
        self.parent.lock
    }
    
    fileprivate let subscription = SingleAssignmentDisposable()
    
    init(parent: Parent) {
        self.parent = parent
    }
    
    func on(_ event: Event<Element>) {
        self.synchronizedOn(event)
    }
    
    func synchronized_on(_ event: Event<Element>) {
        switch event {
        case .next:
            // 只要有数据, 就通知 parent 结束.
            self.parent.forwardOn(.completed)
            self.parent.dispose()
        case .error(let e):
            self.parent.forwardOn(.error(e))
            self.parent.dispose()
        case .completed:
            self.subscription.dispose()
        }
    }
}

final private class TakeUntilSink<Other, Observer: ObserverType>
: Sink<Observer>
, LockOwnerType
, ObserverType
, SynchronizedOnType {
    typealias Element = Observer.Element
    typealias Parent = TakeUntil<Element, Other>
    
    private let parent: Parent
    
    let lock = RecursiveLock()
    
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<Element>) {
        self.synchronizedOn(event)
    }
    
    func synchronized_on(_ event: Event<Element>) {
        switch event {
        case .next:
            self.forwardOn(event)
        case .error:
            self.forwardOn(event)
            self.dispose()
        case .completed:
            self.forwardOn(event)
            self.dispose()
        }
    }
    
    func run() -> Disposable {
        // 对于 other 进行了注册监听, 当 other 发送了信号之后, 这里立马进入 dispose 状态.
        let otherObserver = TakeUntilSinkOther(parent: self)
        let otherSubscription = self.parent.other.subscribe(otherObserver)
        otherObserver.subscription.setDisposable(otherSubscription)
        
        // 然后, 原来的还是订阅自身. 自身将原来的信号, 原封不动的交给自己的下一个节点.
        let sourceSubscription = self.parent.source.subscribe(self)
        return Disposables.create(sourceSubscription, otherObserver.subscription)
    }
}

final private class TakeUntil<Element, Other>: Producer<Element> {
    
    fileprivate let source: Observable<Element>
    fileprivate let other: Observable<Other>
    
    init(source: Observable<Element>, other: Observable<Other>) {
        self.source = source
        self.other = other
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = TakeUntilSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}

// MARK: - TakeUntil Predicate
final private class TakeUntilPredicateSink<Observer: ObserverType>
: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = TakeUntilPredicate<Element>
    
    private let parent: Parent
    private var running = true
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    // 这里和 Skip 的逻辑是一样的.
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            if !self.running {
                return
            }
            
            do {
                self.running = try !self.parent.predicate(value)
            } catch let e {
                // 当, 出错的时候, 进行 error 的继续传递.
                self.forwardOn(.error(e))
                self.dispose()
                return
            }
            
            // 符合条件, 传输给下一个节点.
            if self.running {
                self.forwardOn(.next(value))
            } else {
                // 不符合条件, 直接 complete.
                if self.parent.behavior == .inclusive {
                    self.forwardOn(.next(value))
                }
                
                self.forwardOn(.completed)
                self.dispose()
            }
        case .error, .completed:
            self.forwardOn(event)
            self.dispose()
        }
    }
    
}

final private class TakeUntilPredicate<Element>: Producer<Element> {
    typealias Predicate = (Element) throws -> Bool
    
    private let source: Observable<Element>
    fileprivate let predicate: Predicate
    fileprivate let behavior: TakeBehavior
    
    init(source: Observable<Element>,
         behavior: TakeBehavior,
         predicate: @escaping Predicate) {
        self.source = source
        self.behavior = behavior
        self.predicate = predicate
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = TakeUntilPredicateSink(parent: self, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
