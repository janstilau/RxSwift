//
//  Just.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/30/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    /*
     Just 其实很有用. 因为 Rx 里面经常有辅助管道, 例如 Merge, FlatMap, 这些都是需要的都是一个新的 Publisher.
     这个新的 Publisher, 仅仅是为了触发某个逻辑, 这个时候使用 Just 就好了.
     这个用法, 就是一个中间量发射了一个信号, 触发主逻辑的后续操作.
     */
    public static func just(_ element: Element) -> Observable<Element> {
        Just(element: element)
    }
    
    // 在特定的 scheduler 上, 进行 Element 的 Emit
    public static func just(_ element: Element,
                            scheduler: ImmediateSchedulerType) -> Observable<Element> {
        JustScheduled(element: element, scheduler: scheduler)
    }
}

final private class JustScheduledSink<Observer: ObserverType>: Sink<Observer> {
    typealias Parent = JustScheduled<Observer.Element>
    
    private let parent: Parent
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    func run() -> Disposable {
        let scheduler = self.parent.scheduler
        /*
         这里只所以要这面写, 和 schedule 的实现相关.
         schedule 返回的是一个可赋值的 disposable.
         没有调度前, 调用 dispose, 是取消调度这件事.
         调度的代码执行后, 调用 dispsoe, 是取消被调度代码的 subscription.
         */
        return scheduler.schedule(self.parent.element) { element in
            self.forwardOn(.next(element))
            return scheduler.schedule(()) { _ in
                self.forwardOn(.completed)
                self.dispose()
                return Disposables.create()
            }
        }
    }
}

final private class JustScheduled<Element>: Producer<Element> {
    fileprivate let scheduler: ImmediateSchedulerType
    fileprivate let element: Element
    
    init(element: Element, scheduler: ImmediateSchedulerType) {
        self.scheduler = scheduler
        self.element = element
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = JustScheduledSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}

final private class Just<Element>: Producer<Element> {
    private let element: Element
    
    init(element: Element) {
        self.element = element
    }
    
    // Producer 的 subscribe 有个固定的套路, 生成一个 SinkDisposer, 然后调用 run 方法, 进行循环引用的建立.
    // 但是, 如果根本不需要这个 Sink 节点, 那么其实可以省略这个节点. 对于这种 Producer, 它的 subscribe 会被重写.
    // 直接在方法内, 触发后续节点的 On 事件就可以了 .
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        observer.on(.next(self.element))
        observer.on(.completed)
        return Disposables.create()
    }
}
