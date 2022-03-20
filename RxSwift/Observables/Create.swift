
extension ObservableType {
    
    /*
     我们给对方传递一个闭包过去, 就是希望对方调用这个闭包.
     分析过源码, 对方会创建一个 Observer, 传入到这个闭包内.
     在这个闭包内, 一般是创建一个异步函数, 然后在异步结果确定时, 调用 Observer 的状态修改函数.
     */
    
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
