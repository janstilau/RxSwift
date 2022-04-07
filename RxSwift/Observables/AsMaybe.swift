/*
 // 可能, 会有一个 next 事件, 然后是 complete 事件.
 // 或者, 直接是 complete 事件.
 
 看起来和普通 Observable 没有任何区别, 它的主要限制在于, 如果有 next 事件, 一定只有一次, 然后紧接着就是 Complete 事件了.
 */
private final class AsMaybeSink<Observer: ObserverType> : Sink<Observer>, ObserverType {
    
    typealias Element = Observer.Element
    
    private var element: Event<Element>? // 会存储, 上一个 next 的值.
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            // 在第一次收到数据之后, 没有直接进行 forward, 而是存起来.
            // 如果收到了两次 Next, 直接报错, 原来存储的 ele 也不会进行发送 .
            if self.element != nil {
                self.forwardOn(.error(RxError.moreThanOneElement))
                self.dispose()
            }
            // 只, 记录一个 event 的数据.
            self.element = event
        case .error:
            self.forwardOn(event)
            self.dispose()
        case .completed:
            // 直到 Complete 的时候, 才会发送原有的 Next 中存储的 Element 数据. 
            if let element = self.element {
                self.forwardOn(element)
            }
            self.forwardOn(.completed)
            self.dispose()
        }
    }
}

final class AsMaybe<Element>: Producer<Element> {
    private let source: Observable<Element>
    
    init(source: Observable<Element>) {
        self.source = source
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = AsMaybeSink(observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
