//
//  Producer.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/20/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//


/*
 Producer 中, 记录的是事件发生的时候的处理逻辑, 并不会立刻对事件进行处理.
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
     返回 Sink 对象, 以及存储的 Source 注册这个 Sink 返回的 Subscription 对象.
     
     Publisher()->Map->Filter->Subject
     
     在以上的这个链条里面, 当 Filter Subscribe Subject 的时候, 返回的是一个 SinkDisposer 对象.
     SinkDisposer 对象里面, 存储着 FilterSink 对象, 以及 Map Subscribe FilterSink 的返回值, 还是一个 SinkDisposer 对象.
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
    private var sink: Disposable? // 使用这个值, 保留了新生成的 Sink 对象的生命周期.
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
    
    func dispose() {
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
            
            sink.dispose()
            subscription.dispose()
            
            // 主动, 放开引用, 放开了循环引用. 这里非常重要, Sink 的生命周期, 其实是靠 Sink 和 SinkDisposer 循环引用保持的.
            self.sink = nil
            self.subscription = nil
        }
    }
}
