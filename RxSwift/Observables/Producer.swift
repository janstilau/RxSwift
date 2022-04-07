//
//  Producer.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/20/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//


/*
 各种, Operator 的执行结果, 返回的是一个 Producer 对象.
 而 Producer 是一个 Observable. 所以, 它能够继续调用 Observable 的方法, 也能最终调用 subscribe 函数.
 
 各种 Observable 的方法, 仅仅是在做数据收集的工作. 真正的这些数据能够起到作用, 是在 Sink 中.
 
 而各个 Producer 的 subscribe 方法中, 实际上是生成了各个 Sink 对象. 各个 Sink 对象, 是 Observer.
 在 Producer 调用 subscribe 的时候, 是实际的 Sink 的生成, 并且串连起来的过程.
 各个 Observable 在各个响应链路中, 对象消失, 是一个个 Sink 串连, 并且将各自的指针, 插入到前方节点中进行保存.
 */
class Producer<Element>: Observable<Element> {
    
    override init() {
        super.init()
    }
    
    /*
     Producer 并不是实际的相应联调上的节点对象, 它是节点的生产者.
     当真正的需要订阅的时候, Producer 才会生成 Sink 节点, 添加到响应链条里面.
     一般来说, 一个 Publisher, 很多的 Operator, 然后终点是一个 Subscriber.
     */
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        if !CurrentThreadScheduler.isScheduleRequired {
            // The returned disposable needs to release all references once it was disposed.
            let disposer = SinkDisposer()
            let sinkAndSubscription = self.run(observer, cancel: disposer)
            disposer.setSinkAndSubscription(sink: sinkAndSubscription.sink,
                                            subscription: sinkAndSubscription.subscription)
            return disposer
        } else {
            return CurrentThreadScheduler.instance.schedule(()) { _ in
                let disposer = SinkDisposer()
                let sinkAndSubscription = self.run(observer, cancel: disposer)
                disposer.setSinkAndSubscription(sink: sinkAndSubscription.sink, subscription: sinkAndSubscription.subscription)
                
                return disposer
            }
        }
    }
    
    /*
     子类, 子类化 run 的具体实现.
     返回 Sink 对象, 以及返回的 Subscription 对象.
     
     Publisher()->Map->Filter->Subject
     
     在以上的这个链条里面, 当 Filter Subscribe Subject 的时候, 返回的是一个 SinkDisposer 对象.
     SinkDisposer 对象里面, 存储着 FilterSink 对象, 以及 Map Subscribe FilterSink 的返回值, 还是一个 SinkDisposer 对象.
     Filter 的 Subscribe 方法, 会触发它的 source 的 subscribe 的方法. 就是这样, 将真正的响应者链条进行了串连.
     FilterDisposer - MapDisposer - PublisherDisposer
     |               |
     FilterSink        MapSink
     
     最终返回的是 FilterDisposer, 通过上面的关系, 可以看到, FilterDisposer 的 Dispose 可以引起整个链条的 Dispose 触发.
     */
    func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable)
    where Observer.Element == Element {
        rxAbstractMethod()
    }
}

private final class SinkDisposer: Cancelable {
    
    private enum DisposeState: Int32 {
        case disposed = 1 // 已经 disposde 了.
        case sinkAndSubscriptionSet = 2 // 被 subscribe 了, 还没有被 disposed.
    }
    
    private let state = AtomicInt(0) // 初始状态, 还没有被 subscribe 的
    private var sink: Disposable? // 这是一个循环引用, 保证了节点, 只有在 Dispose 触发的时候, 才会真正的消亡. 
    /*
     Map.Filter.Subscribe
     
     FilterProducer 的 Subscribe, 返回一个 SinkDisposer
     SinkDisposer 中引用了 FilterSink. 以及 MapProducer Subscribe FilterSink 的返回值. 而这个返回值, 引用了 MapSink.
     
     通过这种联调, 最后返回的 Dispose 对象, 在调用 dispose 的时候, 会让链条上所有生成的 Subscription 对象, 都能够调用 dispose.
     */
    private var subscription: Disposable? // 使用这个值, Source 注册 Sink 的返回值被保留了.
    
    var isDisposed: Bool {
        isFlagSet(self.state, DisposeState.disposed.rawValue)
    }
    
    func setSinkAndSubscription(sink: Disposable, subscription: Disposable) {
        self.sink = sink
        self.subscription = subscription
        
        let previousState = fetchOr(self.state, DisposeState.sinkAndSubscriptionSet.rawValue)
        if (previousState & DisposeState.sinkAndSubscriptionSet.rawValue) != 0 {
            rxFatalError("Sink and subscription were already set")
        }
        
        // 如果, 自身的状态已经是 disposed 了, 那么新加入的 sink 和 subscription, 都要进行 dispose.
        if (previousState & DisposeState.disposed.rawValue) != 0 {
            sink.dispose()
            subscription.dispose()
            // 主动, 放开引用, 放开了循环引用.
            self.sink = nil
            self.subscription = nil
        }
    }
    
    /*
     Sink 是当前 Sink 对象, 通过这个循环引用, 可以保证 Sink 可以自管理. 必须明确的调用 dispose 之后, Sink 对象才会消失.
     Subscription 则是前方节点的 SinkDisposer 引用.
     Sink 的 dispose, 可能是从后向前触发, 就是最后的 subscription 调用 Dispose, 顺着 Subscription 触发. 这个时候, 上游节点的 Subscription 会触发 dispose 操作.
     也可能是从前往后触发, 上游节点已经 dispose 了, 但是下游节点还是会触发上游节点的 dispose. 所以, 要在 dispose 内进行状态的判断, 避免重复 dispose 逻辑被调用了. 
     */
    func dispose() {
        // fetchOr 会修改 self.state 的值.
        // 所以第二次进入的时候, 不会引起这个方法的递归调用.
        let previousState = fetchOr(self.state, DisposeState.disposed.rawValue)
        
        // 已经 disposded, 直接返回, 防止重复 dispose.
        // 这个是十分必要的, 因为触发 dispose 的时机会很多. complete Event 事件会触发. 返回的 subscription 会触发. 所以, 应该进行拦截.
        if (previousState & DisposeState.disposed.rawValue) != 0 {
            return
        }
        
        // 然后进行自己管理的 sink, 和 subscription 的 dispose 操作.
        if (previousState & DisposeState.sinkAndSubscriptionSet.rawValue) != 0 {
            guard let sink = self.sink else {
                rxFatalError("Sink not set")
            }
            guard let subscription = self.subscription else {
                rxFatalError("Subscription not set")
            }
            
            // Sink dispose 会修改 Sink 的状态, Sink 的状态为 Disposed 了, 就不会 forward 任何的事件了.
            sink.dispose()
            // 然后才是 subscription 的 Dispose. 这个顺序是非常重要的. 因为 subscription.dispose() 还是可能会触发事件的, 例如 dataTaskRequest 的 cancel, 但是因为 Sink 先 disposed 了, 后续节点, 还是不会受到取消事件.
            subscription.dispose()
            
            // 主动, 放开引用, 放开了循环引用. 这里非常重要, Sink 的生命周期, 其实是靠 Sink 和 SinkDisposer 循环引用保持的.
            self.sink = nil
            self.subscription = nil
        }
    }
}
