extension ObservableType {
    
    /*
     Continues an observable sequence that is terminated by an error with
     the observable sequence produced by the handler.
     */
    public func `catch`(_ handler: @escaping (Swift.Error) throws -> Observable<Element>)
    -> Observable<Element> {
        Catch(source: self.asObservable(), handler: handler)
    }
    
    // 当发生错误之后, 直接使用 element 产生一个新的队列.
    // ReplaceError
    public func catchAndReturn(_ element: Element)
    -> Observable<Element> {
        // 当, 发生了错误之后, 产生一个 element 的 next 信号, 然后整个信号序列结束了.
        Catch(source: self.asObservable(), handler: { _ in Observable.just(element) })
    }
}

extension ObservableType {
    public static func `catch`<Sequence: Swift.Sequence>(sequence: Sequence) -> Observable<Element>
    where Sequence.Element == Observable<Element> {
        CatchSequence(sources: sequence)
    }
}

extension ObservableType {
    
    /*
     Repeats the source observable sequence until it successfully terminates.
     
     **This could potentially create an infinite sequence.**
     
     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)
     
     - returns: Observable sequence to repeat until it successfully terminates.
     */
    public func retry() -> Observable<Element> {
        CatchSequence(sources: InfiniteSequence(repeatedValue: self.asObservable()))
    }
    
    /*
     Repeats the source observable sequence the specified number of times in case of an error or until it successfully terminates.
     If you encounter an error and want it to retry once, then you must use `retry(2)`
     */
    public func retry(_ maxAttemptCount: Int)
    -> Observable<Element> {
        CatchSequence(sources: Swift.repeatElement(self.asObservable(), count: maxAttemptCount))
    }
}

// catch with callback

final private class CatchSinkProxy<Observer: ObserverType>: ObserverType {
    typealias Element = Observer.Element
    typealias Parent = CatchSink<Observer>
    
    private let parent: Parent
    
    init(parent: Parent) {
        self.parent = parent
    }
    
    // 无论是接收到什么样的信号, Parent 都转交给自己的下游节点.
    func on(_ event: Event<Element>) {
        self.parent.forwardOn(event)
        switch event {
        case .next:
            break
        case .error, .completed:
            self.parent.dispose()
        }
    }
}

final private class CatchSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    
    // Rx 里面, 大量使用了 typealias.
    typealias Element = Observer.Element
    typealias Parent = Catch<Element>
    
    private let parent: Parent
    private let subscription = SerialDisposable()
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    func run() -> Disposable {
        let d1 = SingleAssignmentDisposable()
        self.subscription.disposable = d1
        // 让 Sink 来注册, 原本的 Source 的信号.
        d1.setDisposable(self.parent.source.subscribe(self))
        return self.subscription
    }
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            self.forwardOn(event)
        case .completed:
            self.forwardOn(event)
            self.dispose()
        case .error(let error):
            // 当发生错误之后, 不会将错误, 传递给自己的下游节点.
            do {
                // 使用之前存储的根据 Error 生成 Sequence 的 Handler, 生成一个新的 Publisher
                let catchSequence = try self.parent.handler(error)
                let observer = CatchSinkProxy(parent: self)
                /*
                 原来的上游节点, 在 error 之后, 应该自己进行 dispsoe.
                 CatchSink 当前节点的上游, 替换成为了新生成的 catchSequence Publisher.
                 */
                self.subscription.disposable = catchSequence.subscribe(observer)
            } catch let e {
                self.forwardOn(.error(e))
                self.dispose()
            }
        }
    }
}

final private class Catch<Element>: Producer<Element> {
    
    // 从一个 Error, 产生一个 Sequence.
    typealias Handler = (Swift.Error) throws -> Observable<Element>
    
    fileprivate let source: Observable<Element>
    fileprivate let handler: Handler
    
    init(source: Observable<Element>, handler: @escaping Handler) {
        self.source = source
        self.handler = handler
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = CatchSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}

// catch enumerable

final private class CatchSequenceSink<Sequence: Swift.Sequence, Observer: ObserverType>
: TailRecursiveSink<Sequence, Observer>
, ObserverType where Sequence.Element: ObservableConvertibleType, Sequence.Element.Element == Observer.Element {
    
    typealias Element = Observer.Element
    typealias Parent = CatchSequence<Sequence>
    
    private var lastError: Swift.Error?
    
    override init(observer: Observer, cancel: Cancelable) {
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            self.forwardOn(event)
        case .error(let error):
            self.lastError = error
            // 当, 发生了错误之后, 开始注册下一个序列中的下一个 Source, 当做自己节点的源头.
            self.schedule(.moveNext)
        case .completed:
            self.forwardOn(event)
            self.dispose()
        }
    }
    
    override func subscribeToNext(_ source: Observable<Element>) -> Disposable {
        // source, 是从 Sequence Iter 中, 获取新的 Publisher, 将这个 Publisher 挂钩到 Self 上, Self 接受新的事件
        // 如果发生了错误, self.schedule(.moveNext) 会从 Sequence Iter 获取新的 Publisher, 再次挂钩.
        source.subscribe(self)
    }
    
    override func done() {
        if let lastError = self.lastError {
            self.forwardOn(.error(lastError))
        }
        else {
            self.forwardOn(.completed)
        }
        
        self.dispose()
    }
    
    override func extract(_ observable: Observable<Element>) -> SequenceGenerator? {
        if let onError = observable as? CatchSequence<Sequence> {
            return (onError.sources.makeIterator(), nil)
        }
        else {
            return nil
        }
    }
}

final private class CatchSequence<Sequence: Swift.Sequence>: Producer<Sequence.Element.Element> where Sequence.Element: ObservableConvertibleType {
    typealias Element = Sequence.Element.Element
    
    let sources: Sequence
    
    init(sources: Sequence) {
        self.sources = sources
    }
    
    override func run<Observer: ObserverType>(
        _ observer: Observer,
        cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
            let sink = CatchSequenceSink<Sequence, Observer>(observer: observer, cancel: cancel)
            let subscription = sink.run((self.sources.makeIterator(), nil))
            return (sink: sink, subscription: subscription)
        }
}
