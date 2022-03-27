
// 最最最重要的方法.
// 将指令式的世界, 纳入到响应式世界的关键就在这. 
extension ObservableType {
    public static func create(_ subscribe: @escaping (AnyObserver<Element>) -> Disposable) -> Observable<Element> {
        AnonymousObservable(subscribe)
    }
}

final private class AnonymousObservableSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    
    typealias Element = Observer.Element
    typealias Parent = AnonymousObservable<Element>
    
    private let isStopped = AtomicInt(0)
    
    override init(observer: Observer, cancel: Cancelable) {
        super.init(observer: observer, cancel: cancel)
    }
    
    // 这个观察者, 没有特殊的逻辑, 就是传递数据.
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            if load(self.isStopped) == 1 {
                return
            }
            self.forwardOn(event)
        case .error, .completed:
            if fetchOr(self.isStopped, 1) == 0 {
                self.forwardOn(event)
                self.dispose()
            }
        }
    }
    
    // run 在 Subscribe 的时候被调用.
    // parent.subscribeHandler 一般会建立异步任务, 然后这个异步任务的信号发射, 是通过调用参数的 OnNext, OnError, OnComplete, 来传递给后面的各个节点的. 
    func run(_ parent: Parent) -> Disposable {
        // 将自身, 当做观察者, 传递给被传递的闭包中.
        parent.subscribeHandler(AnyObserver(self))
    }
}

final private class AnonymousObservable<Element>: Producer<Element> {
    
    typealias SubscribeHandler = (AnyObserver<Element>) -> Disposable
    
    // 会存储, 如何产生 信号流.
    let subscribeHandler: SubscribeHandler
    
    init(_ subscribeHandler: @escaping SubscribeHandler) {
        self.subscribeHandler = subscribeHandler
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = AnonymousObservableSink(observer: observer, cancel: cancel)
        let subscription = sink.run(self)
        return (sink: sink, subscription: subscription)
    }
}
