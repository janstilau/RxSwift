// 要么是 ele + comlete, 要么是 error
// 所以 AsSingleSink 其实就是对于它的 Source 提要求, 如果不满足要求, 就发送 error 到后续的节点.
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
            // 当 Complete 的时候, 必须是接受过 Next 信号, 存储过值, 否则就是 error. 
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
