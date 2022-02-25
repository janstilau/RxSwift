
// 可能, 会有一个 next 事件, 然后是 complete 事件.
// 或者, 直接是 complete 事件.
private final class AsMaybeSink<Observer: ObserverType> : Sink<Observer>, ObserverType {
    
    typealias Element = Observer.Element
    
    private var element: Event<Element>?
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            // 如果, 有多个 next 事件发生, 那么就报错.
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
            // 如果, 有了 next 的事件发生了, 那么发送这个数据.
            // 所以这个 Sink 只会在 complete 的时候, 发送 next 事件给后续节点.
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
