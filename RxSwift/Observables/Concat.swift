

extension ObservableType {
    public func concat<Source: ObservableConvertibleType>(_ second: Source) -> Observable<Element> where Source.Element == Element {
        Observable.concat([self.asObservable(), second.asObservable()])
    }
}

extension ObservableType {
    /*
     Concatenates all observable sequences in the given sequence, as long as the previous observable sequence terminated successfully.
     */
    public static func concat<Sequence: Swift.Sequence>(_ sequence: Sequence) -> Observable<Element>
    where Sequence.Element == Observable<Element> {
        return Concat(sources: sequence, count: nil)
    }
    
    /*
     Concatenates all observable sequences in the given collection, as long as the previous observable sequence terminated successfully.
     */
    public static func concat<Collection: Swift.Collection>(_ collection: Collection) -> Observable<Element>
    where Collection.Element == Observable<Element> {
        return Concat(sources: collection, count: Int64(collection.count))
    }
    
    /**
     Concatenates all observable sequences in the given collection, as long as the previous observable sequence terminated successfully.
     */
    public static func concat(_ sources: Observable<Element> ...) -> Observable<Element> {
        Concat(sources: sources, count: Int64(sources.count))
    }
}

final private class ConcatSink<Sequence: Swift.Sequence, Observer: ObserverType>
: TailRecursiveSink<Sequence, Observer>
, ObserverType where Sequence.Element: ObservableConvertibleType, Sequence.Element.Element == Observer.Element {
    typealias Element = Observer.Element
    
    override init(observer: Observer, cancel: Cancelable) {
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<Element>){
        switch event {
        case .next:
            self.forwardOn(event)
        case .error:
            self.forwardOn(event)
            self.dispose()
        case .completed:
            self.schedule(.moveNext)
        }
    }
    
    // 只有, 前面的 source Complete 的时候, 才会监听后面的 source.
    // 所以, 在前面的 source 没有完成信号 complete 的发射的时候, 后面的 source 信号发射会被忽略. 
    override func subscribeToNext(_ source: Observable<Element>) -> Disposable {
        source.subscribe(self)
    }
    
    override func extract(_ observable: Observable<Element>) -> SequenceGenerator? {
        if let source = observable as? Concat<Sequence> {
            return (source.sources.makeIterator(), source.count)
        } else {
            return nil
        }
    }
}



final private class Concat<Sequence: Swift.Sequence>: Producer<Sequence.Element.Element> where Sequence.Element: ObservableConvertibleType {
    typealias Element = Sequence.Element.Element
    
    // 存储了所有的 source
    fileprivate let sources: Sequence
    fileprivate let count: IntMax?
    
    init(sources: Sequence, count: IntMax?) {
        self.sources = sources
        self.count = count
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = ConcatSink<Sequence, Observer>(observer: observer, cancel: cancel)
        let subscription = sink.run((self.sources.makeIterator(), self.count))
        return (sink: sink, subscription: subscription)
    }
}

