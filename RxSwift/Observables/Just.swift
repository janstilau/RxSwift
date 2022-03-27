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
     如果我们有着明确的输出, 那么使用 Just 就可以了.
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
    
    // Just, 完全重写了父类的 subscribe 方法. 返回了一个 FakeDisposable.
    // 当一个 Just 进行 subscribe 的时候, 直接就是将存储的值, 发送给 observer, 然后结束.
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        observer.on(.next(self.element))
        observer.on(.completed)
        return Disposables.create()
    }
}
