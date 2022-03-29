//
//  Empty.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/30/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    /*
     Returns an empty observable sequence, using the specified scheduler to send out the single `Completed` message.
     */
    /*
     类方法, 返回实际的逻辑对象, 是一个经常使用的办法.
     类方法, 是一个工厂, 返回一个抽象数据类型, 根据类方法的名称不同, 返回不同的实际对象.
     */
    public static func empty() -> Observable<Element> {
        EmptyProducer<Element>()
    }
}

// Empty 的含义时, 会发送一个 Complete 事件.
final private class EmptyProducer<Element>: Producer<Element> {
    // Empty 的 Operator, 同样不需要一个 Sink 节点, 所以完全重写 subscribe 方法就可以.
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        observer.on(.completed)
        return Disposables.create()
    }
}
