

extension ObservableType {
    public func compactMap<Result>(_ transform: @escaping (Element) throws -> Result?)
    -> Observable<Result> {
        CompactMap(source: self.asObservable(), transform: transform)
    }
}

final private class CompactMapSink<SourceType, Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Transform = (SourceType) throws -> ResultType?
    
    typealias ResultType = Observer.Element
    typealias Element = SourceType
    
    private let transform: Transform
    
    init(transform: @escaping Transform, observer: Observer, cancel: Cancelable) {
        self.transform = transform
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<SourceType>) {
        switch event {
        case .next(let element):
            do {
                // 去除了返回值是 nil 的元素. 对于下游来说, 并不知道, 存在着 value == nil 的信号被发送过来了.
                // 这就是这个类, 最主要的逻辑. 
                if let mappedElement = try self.transform(element) {
                    self.forwardOn(.next(mappedElement))
                }
            } catch let e {
                self.forwardOn(.error(e))
                self.dispose()
            }
        case .error(let error):
            self.forwardOn(.error(error))
            self.dispose()
        case .completed:
            self.forwardOn(.completed)
            self.dispose()
        }
    }
}

final private class CompactMap<SourceType, ResultType>: Producer<ResultType> {
    typealias Transform = (SourceType) throws -> ResultType?
    
    private let source: Observable<SourceType>
    
    private let transform: Transform
    
    init(source: Observable<SourceType>, transform: @escaping Transform) {
        self.source = source
        self.transform = transform
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == ResultType {
        let sink = CompactMapSink(transform: self.transform, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
