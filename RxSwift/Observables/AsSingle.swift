
// 必须要有一个 next 事件, 然后是 complete 事件.
// 如果没有 next 事件, 或者多个事件, 那么会报错. 
private final class AsSingleSink<Observer: ObserverType> : Sink<Observer>, ObserverType {
    typealias Element = Observer.Element
    
    private var element: Event<Element>?
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            if self.element != nil {
                // 如果接收到了多个 element, 发送一个错误的信号到下游.
                self.forwardOn(.error(RxError.moreThanOneElement))
                self.dispose()
            }
            
            self.element = event
        case .error:
            self.forwardOn(event)
            self.dispose()
        case .completed:
            if let element = self.element {
                self.forwardOn(element)
                self.forwardOn(.completed)
            } else {
                self.forwardOn(.error(RxError.noElements))
            }
            self.dispose()
        }
    }
}

final class AsSingle<Element>: Producer<Element> {
    private let source: Observable<Element>
    
    init(source: Observable<Element>) {
        self.source = source
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = AsSingleSink(observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
