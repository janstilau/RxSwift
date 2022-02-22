//
//  Sink.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

class Sink<Observer: ObserverType>: Disposable {
    
    fileprivate let observer: Observer // Sink 操作后数据后, 应该传递数据的去向
    fileprivate let cancel: Cancelable
    private let disposed = AtomicInt(0)
    
#if DEBUG
    private let synchronizationTracker = SynchronizationTracker()
#endif
    
    init(observer: Observer, cancel: Cancelable) {
#if TRACE_RESOURCES
        _ = Resources.incrementTotal()
#endif
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
    
    // 将自身的状态, 设置为 disposed
    func dispose() {
        fetchOr(self.disposed, 1)
        // Sink 的 dispose, 仅仅是状态的改变.
        // 真正的取消操作, 是 cancel 的 dispose 进行的. 
        self.cancel.dispose()
    }
    
    deinit {
#if TRACE_RESOURCES
        _ =  Resources.decrementTotal()
#endif
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
