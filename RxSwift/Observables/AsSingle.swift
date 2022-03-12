
/*
 AsSingle 是对于原有的 Publisher 的包装. 为的就是确认, 只会有一次 element 的发射.
 所以, AsSingleSink 要保证, 所包装的 Publisher 要有 single 的特性. 这一点, 是通过建立一个 AsSingleSink 中间层达到的.
 原来的 Publisher 还是原有的方式发射信号, 在 SingleSink 这里进行拦截. 
 */
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
