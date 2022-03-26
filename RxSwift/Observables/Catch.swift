/*
 当, error 数据来临之后, 之前的节点都已经 dispsoe 掉了
 使用一个 handler, 创建一个新的数据源头, 继续保持响应链条.
 */

extension ObservableType {
    
    /*
     Continues an observable sequence that is terminated by an error with
     the observable sequence produced by the handler.
     */
    /*
     监听一个事件序列, 当这个事件序列发生错误之后, 不会进行 Dispose, 而是使用 handler 生成一个新的事件序列, 继续监听这个新生成的事件序列.
     */
    public func `catch`(_ handler: @escaping (Swift.Error) throws -> Observable<Element>)
    -> Observable<Element> {
        Catch(source: self.asObservable(), handler: handler)
    }
    
    // 当发生错误之后, 直接使用 element 产生一个新的队列.
    // 有了上面的通用的设计, 对于返回一个确定值的情况, 就是使用 Observable.just 生成一个事件序列, 然后返回那个值就可以了.
    public func catchAndReturn(_ element: Element)
    -> Observable<Element> {
        // 当, 发生了错误之后, 产生一个 element 的 next 信号, 然后整个信号序列结束了.
        Catch(source: self.asObservable(), handler: { _ in Observable.just(element) })
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
    // 通过在里面增加一层, 确保了, 不能再次进行 catch 了
    func on(_ event: Event<Element>) {
        self.parent.forwardOn(event)
        switch event {
        case .next:
            break
        case .error, .completed:
            // 如果是结束事件, 那么直接调用 parent 的 dipose.
            // 这是合理的做法, catch handler 生成的 Sequence, 不会触发 CatchSink 的 on 逻辑, 而是将所有的 event 交给了 CatchSinkProxy 来处理
            // 不这样, CatchSink 再次触发 error, 那么就无限循环了.
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
        // CatchSink 还是成为原来的 Source 的 Observer.
        d1.setDisposable(self.parent.source.subscribe(self))
        return self.subscription
    }
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            // 正常的数据, 直接 forward.
            self.forwardOn(event)
        case .completed:
            // 结束事件, 直接 forward 然后 dispose.
            self.forwardOn(event)
            self.dispose()
        case .error(let error):
            // 当发生错误之后, 不会将错误, 传递给自己的下游节点.
            do {
                // 使用之前存储的根据 Error 生成 Sequence 的 Handler, 生成一个新的 Publisher
                let catchSequence = try self.parent.handler(error)
                let observer = CatchSinkProxy(parent: self)
                // subscription 的赋值, 会导致之前的 disposable 触发 dispose 的.
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

extension ObservableType {
    // 如果, 一个 Swift.Sequence 里面的元素, 都是一个 Publisher 的话, 会生成 CatchSequence
    public static func `catch`<Sequence: Swift.Sequence>(sequence: Sequence) -> Observable<Element>
    where Sequence.Element == Observable<Element> {
        CatchSequence(sources: sequence)
    }
}



/*
 
 */

extension ObservableType {
    
    // 如果, 失败了, 那么使用原来的 Publisher 再次生成响应链条. 直到正常的 Complete.
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
    // 如果失败了, 使用原来的 Publisher 再次生成响应链条. 有最大的重复次数.
    public func retry(_ maxAttemptCount: Int)
    -> Observable<Element> {
        CatchSequence(sources: Swift.repeatElement(self.asObservable(), count: maxAttemptCount))
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
    
    // 取得了下一个 Publisher, 应该怎么处理. 在子类中重写, 这里就是直接将和自己相连.
    override func subscribeToNext(_ source: Observable<Element>) -> Disposable {
        // 获取下一个 Publisher, 然后 Publisher 构建原有的响应链条的源头.
        source.subscribe(self)
    }
    
    override func done() {
        if let lastError = self.lastError {
            self.forwardOn(.error(lastError))
        } else {
            self.forwardOn(.completed)
        }
        self.dispose()
    }
    
    override func extract(_ observable: Observable<Element>) -> SequenceGenerator? {
        if let onError = observable as? CatchSequence<Sequence> {
            return (onError.sources.makeIterator(), nil)
        } else {
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
    
    // 这种, 另起一行将参数顶头写的方式, 是官方推荐的写法.
    override func run<Observer: ObserverType>(
        _ observer: Observer,
        cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
            let sink = CatchSequenceSink<Sequence, Observer>(observer: observer, cancel: cancel)
            let subscription = sink.run((self.sources.makeIterator(), nil))
            return (sink: sink, subscription: subscription)
        }
}
