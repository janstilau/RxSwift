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
 最终的响应链条里面, 其实就是一个个 Sink 的链接. 中间可能会有 Subject, 数据从最初的节点, 流转到后面的节点.
 这个流转的过程, 不同的 Sink 类有自己的实现. 可能会有线程间调度, 也可能会缓存, 但是方向是不变的, 从前到后.
 这也表明了异步编程的常用套路, 只要各个回调, 按照顺序触发就可以. 中间是可以有延迟和环境切换的.
 它们的作用, 是通用的, 方便他人阅读, 颗粒度小, 具有良好架构能力的人, 可以使用这些, 写出流式清晰的代码.
 */

class Sink<Observer: ObserverType>: Disposable {
    
    // Sink 和 自己的
    fileprivate let observer: Observer // Sink 操作后数据后, 应该传递数据的去向
    fileprivate let cancel: Cancelable // 一般来说是 SinkDisposer
    
    private let disposed = AtomicInt(0)
    
    init(observer: Observer, cancel: Cancelable) {
        // 存储响应联调的下一个节点, Sink 有一个非常大的责任, 就是将信号数据, 传递给下一个节点. 所以必须要存储.
        self.observer = observer
        // 这个传递过来的 cancel, 一般是一个 SinkDisposer.
        // SinkDisposer 会强引用自己, 这里会有一个循环引用. 这个循环引用, 会在 dispose 里面打破
        // 这是一个故意设计出来的机制, 因为, 响应链条的生命周期是不会交给外界处理的, 只会在 dispose 中进行相关的释放工作.
        // 引用循环在这里创建. 
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
    
    func dispose() {
        // 将自身的状态, 设置为 disposed
        let _ = fetchOr(self.disposed, 1)
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
