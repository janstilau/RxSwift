// 最最最重要的方法.
// 将指令式的世界, 纳入到响应式世界的关键就在这.

extension ObservableType {
    public static func create(_ subscribe: @escaping (AnyObserver<Element>) -> Disposable) -> Observable<Element> {
        AnonymousObservable(subscribe)
    }
}

// Producer 的作用, 就是生成出 Sink 对象. 真正的响应链条里面, 就是一个个 Sink 相连.
// 实际上, 相应链条就是一个个 Sink, 根本就没有 Observable. 这是一个抽象的概念.
// 源头的 Sink 对象, 被调用 On 方法, 就是 Observable 发射了一条信号.
/*
 这个概念信号槽那里也是一样的.
 发射信号, 就是所有监听者收到信号的数据.
 */
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
    
    // Create 方法创建的, AnonymousObservableSink, 是所有的信号发射的源头.
    // 它的状态变化, 传递给后面的 Sink 对象, 后面的 Sink 对象, 有着自己对于这个信号的处理逻辑. 
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
