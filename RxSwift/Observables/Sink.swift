//
//  Sink.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 大部分的 Sink, 都是 Observer, 接受上游的信号, 完成自己的业务逻辑处理后, 将信号 forward 给自己的下游. 
 */

/*
 RxSwift 的强大之处, 就在于各种 Operation, 以及真正实现了 Operator 逻辑的 Sink 类.
 这些小的工具类, 就如同 Sequence 的各种函数式方法一样, 具有组合的能力.
 它们的作用, 是通用的, 方便他人阅读, 颗粒度小, 具有良好架构能力的人, 可以使用这些, 写出流式清晰的代码.
 */
class Sink<Observer: ObserverType>: Disposable {
    
    // 实际上, 在这里, Sink 是保存了它的一下个节点的生命周期的.
    fileprivate let observer: Observer // Sink 操作后数据后, 应该传递数据的去向
    fileprivate let cancel: Cancelable
    
    private let disposed = AtomicInt(0)
    
#if DEBUG
    private let synchronizationTracker = SynchronizationTracker()
#endif
    
    // 这个传递过来的 cancel, 一般是一个 SinkDisposer.
    // 在这里会引起循环引用, 保证了 Sink 的生命周期, 这是特意设计出来的循环引用.
    init(observer: Observer, cancel: Cancelable) {
        self.observer = observer
        self.cancel = cancel
    }
    
    final func forwardOn(_ event: Event<Observer.Element>) {
        // 如果, 自身已经 disposed 了, 那么就不接受后续发射的信号了.
        if isFlagSet(self.disposed, 1) {
            return
        }
        // 将, 数据直接交给 observer. 这个数据, 一般是经过 sink 加工后的数据.
        self.observer.on(event)
    }
    
    final func forwarder() -> SinkForward<Observer> {
        SinkForward(forward: self)
    }
    
    final var isDisposed: Bool {
        isFlagSet(self.disposed, 1)
    }
    
    /*
     这里的逻辑有点怪.
     如果, 是 Stop 事件到达了, 触发 Sink 的 dispose
     Sink 的 Dispose 仅仅会进行状态的改变, 然后调用 cancel 的 dispose. Sink 的 cancel 一般是一个 SinkDisposer. 和 Sink 进行循环引用.
     SinkDisposer 里面有 Sink 和 上一个 PUBLISER Subscribe 这个 Sink 返回的 Subscription.
     SinkDisposer 会触发 Sink 和 Subscription 的 Dispose.
     所以 Sink 又一次会被 dispsoe. 然后再次到达 SinkDisposer 的 Dispose, return 掉.
     
     这样的设计, 是无论是因为 Event 到达, Sink 进行 Dispose, 或者 Subscription dispose. 都会让 Subscription 的 dispose 触发,
     Subscription 的 dispose 触发, 会引起 Sink 和 SinkDispose 之间的循环引用打破, Sink 可以被释放.
     Subscription 的 dispose 触发, 会引起它存储的链条上游的 Subscription 的 dispose 触发.
     所以, Subscription 的 dispose 可能会触发很多次, 但是因为里面有剪枝操作, 所以不会引起问题.
     Sink 的 dispose 多次触发没什么问题, 仅仅是状态的改变.
     */
    func dispose() {
        // 将自身的状态, 设置为 disposed
        fetchOr(self.disposed, 1)
        // Sink 的 dispose, 仅仅是状态的改变.
        // 真正的取消操作, 是 cancel 的 dispose 进行的. 
        self.cancel.dispose()
    }
}

final class SinkForward<Observer: ObserverType>: ObserverType {
    typealias Element = Observer.Element
    
    private let forward: Sink<Observer>
    
    init(forward: Sink<Observer>) {
        self.forward = forward
    }
    
    final func on(_ event: Event<Element>) {
        switch event {
        case .next:
            self.forward.observer.on(event)
        case .error, .completed:
            self.forward.observer.on(event)
            self.forward.cancel.dispose()
        }
    }
}
