/// Supports push-style iteration over an observable sequence.
/*
 观察者的抽象是, 有一个 On 函数.
 也就是说, 可以通过该类型, 不断的处理事件. 这些事件, 是外界主动 Push 过来的.
 */
public protocol ObserverType {
    associatedtype Element
    func on(_ event: Event<Element>)
}

/*
 大部分的情况下, 要么是发送正常数据信号, 要么是发送完成, 错误信号.
 使用对象包装数据是正确的, 可以简化处理流程. 但是, 对外的接口, 应该足够简单, 方便外界使用.
 针对 Enum 专门制定接口, 是一件经常做的事情. 
 */
extension ObserverType {
    
    /// Convenience method equivalent to `on(.next(element: Element))`
    ///
    /// - parameter element: Next element to send to observer(s)
    public func onNext(_ element: Element) {
        self.on(.next(element))
    }
    
    /// Convenience method equivalent to `on(.completed)`
    public func onCompleted() {
        self.on(.completed)
    }
    
    /// Convenience method equivalent to `on(.error(Swift.Error))`
    /// - parameter error: Swift.Error to send to observer(s)
    public func onError(_ error: Swift.Error) {
        self.on(.error(error))
    }
}
