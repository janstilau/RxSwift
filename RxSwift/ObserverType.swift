/*
 官方文档, 说的很抽象. 发射个信号, 然后后面的观察者接收到信号触发各自的方法.
 对于信号发送, 只有 NotificationCenter 做到了信号发送的含义. 它将所有的注册监听, 信号发送收集到了自己的内部.
 
 对于传统的监听者模式来说, 就是将观察者的信息, 存储到被观察者的内部.
 这样, 发射信号, 其实就是找到自己存储的被观察者, 然后调用被观察者的方法.
 
 所以, subscribe 就是建立监听内存数据结构的地方, on 则是通过这个内存数据结构, 触发监听的地方.
 
 不过, 这里由增加了一层抽象. 各种 Subscribe 返回的是一个 Producer, 里面按照不同的 Producer 的业务, 存储了需要的数据.
 真正的注册链条的节点, 是 Producer 产生的 Sink 对象.
 
 这样的设计, 也就导致了, 每次 subscribe 其实是造成了两条信号处理链条. 如果想要共用Publisher, 要用 Share 相关的接口, 创建一个新的 Sink.
 Share Sink 其实就是增加一个中间节点, 然后后续的 subscribe, 都是向这个中间节点中存储 Observers, 这样上游的信号, 会在这个节点进行分发, 也就有了共用的效果了.
 */


/// Supports push-style iteration over an observable sequence.
public protocol ObserverType {
    associatedtype Element
    func on(_ event: Event<Element>)
}

/// Convenience API extensions to provide alternate next, error, completed events
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
