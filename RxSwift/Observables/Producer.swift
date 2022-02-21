//
//  Producer.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/20/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

class Producer<Element>: Observable<Element> {
    
    override init() {
        super.init()
    }

    /*
     Producer 的作用是, 接受上一个 Publisher 的 element, 经过自己的语义进行数据加工, 将加工好的数据, 送到自己保存的 Observer 上.
     一个中间件.
     */
    
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        if !CurrentThreadScheduler.isScheduleRequired {
            // The returned disposable needs to release all references once it was disposed.
            let disposer = SinkDisposer()
            // run 之后, 返回的 sink, 直接引用了 disposer
            let sinkAndSubscription = self.run(observer, cancel: disposer)
            // setSinkAndSubscription 之后, disposer 直接引用了 sink.
            // sinkAndSubscription.subscription 是 source 对于 sink 的 subscribe.
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

    func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        rxAbstractMethod()
    }
}

private final class SinkDisposer: Cancelable {
    
    private enum DisposeState: Int32 {
        case disposed = 1 // 已经 disposde 了.
        case sinkAndSubscriptionSet = 2 // 被 subscribe 了, 还没有被 disposed.
    }

    private let state = AtomicInt(0) // 初始状态, 还没有被 subscribe 的
    private var sink: Disposable?
    private var subscription: Disposable?

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
            // 主动, 放开引用, 放开了循环引用. 
            self.sink = nil
            self.subscription = nil
        }
    }
}
