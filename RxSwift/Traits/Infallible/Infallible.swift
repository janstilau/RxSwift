// 不会失败的序列.
// 其实, 没有特定的限制. 只是少了 onError 的处理 .
// 从下面的快捷方法来看, 也是没有了 error 的处理.

// InfallibleType 就是 ObservableConvertibleType, 没有办法限制, 不会失败. 仅仅是在语义上限制.
public protocol InfallibleType: ObservableConvertibleType {}

// 和 Primitive 一样, 就是包装一个 source 这个值.
// 然后, 在 Infallible 上增加操作. 实际上, 各种纳入到响应链条的操作, 铁定是使用 source
public struct Infallible<Element>: InfallibleType {
    private let source: Observable<Element>
    init(_ source: Observable<Element>) {
        self.source = source
    }
    public func asObservable() -> Observable<Element> { source }
}

extension InfallibleType {
    /*
     Subscribes an element handler, a completion handler and disposed handler to an observable sequence.
     
     Error callback is not exposed because `Infallible` can't error out.
     
     Also, take in an object and provide an unretained, safe to use (i.e. not implicitly unwrapped), reference to it along with the events emitted by the sequence.
     
     - Note: If `object` can't be retained, none of the other closures will be invoked.
     
     - parameter object: The object to provide an unretained reference on.
     - parameter onNext: Action to invoke for each element in the observable sequence.
     - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
     gracefully completed, errored, or if the generation is canceled by disposing subscription)
     - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
     gracefully completed, errored, or if the generation is canceled by disposing subscription)
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    public func subscribe<Object: AnyObject>(
        with object: Object,
        onNext: ((Object, Element) -> Void)? = nil,
        onCompleted: ((Object) -> Void)? = nil,
        onDisposed: ((Object) -> Void)? = nil
    ) -> Disposable {
        self.asObservable().subscribe(
            with: object,
            onNext: onNext,
            onCompleted: onCompleted,
            onDisposed: onDisposed
        )
    }
    
    /**
     Subscribes an element handler, a completion handler and disposed handler to an observable sequence.
     
     Error callback is not exposed because `Infallible` can't error out.
     
     - parameter onNext: Action to invoke for each element in the observable sequence.
     - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
     gracefully completed, errored, or if the generation is canceled by disposing subscription)
     - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
     gracefully completed, errored, or if the generation is canceled by disposing subscription)
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    public func subscribe(onNext: ((Element) -> Void)? = nil,
                          onCompleted: (() -> Void)? = nil,
                          onDisposed: (() -> Void)? = nil) -> Disposable {
        self.asObservable().subscribe(onNext: onNext,
                                      onCompleted: onCompleted,
                                      onDisposed: onDisposed)
    }
    
    /**
     Subscribes an event handler to an observable sequence.
     
     - parameter on: Action to invoke for each event in the observable sequence.
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    public func subscribe(_ on: @escaping (Event<Element>) -> Void) -> Disposable {
        self.asObservable().subscribe(on)
    }
}
