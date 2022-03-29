//
//  Range.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/13/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType where Element: RxAbstractInteger {
    /*
     Generates an observable sequence of integral numbers within a specified range,
     using the specified scheduler to generate and send out observer messages.
     */
    public static func range(start: Element,
                             count: Element,
                             scheduler: ImmediateSchedulerType = CurrentThreadScheduler.instance)
    -> Observable<Element> {
        RangeProducer<Element>(start: start, count: count, scheduler: scheduler)
    }
}

final private class RangeProducer<Element: RxAbstractInteger>: Producer<Element> {
    fileprivate let start: Element
    fileprivate let count: Element
    fileprivate let scheduler: ImmediateSchedulerType
    
    init(start: Element, count: Element, scheduler: ImmediateSchedulerType) {
        self.start = start
        self.count = count
        self.scheduler = scheduler
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = RangeSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}

final private class RangeSink<Observer: ObserverType>: Sink<Observer> where Observer.Element: RxAbstractInteger {
    typealias Parent = RangeProducer<Observer.Element>
    
    private let parent: Parent
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    func run() -> Disposable {
        return self.parent.scheduler.scheduleRecursive(0 as Observer.Element)
        { i, recurse in
            if i < self.parent.count {
                self.forwardOn(.next(self.parent.start + i))
                // 在这里, 进行了递归的调用.
                recurse(i + 1)
            } else {
                // 当, Range 结束了, 直接触发 completed 事件的传递, 然后主动 dispose
                self.forwardOn(.completed)
                self.dispose()
            }
        }
    }
}
