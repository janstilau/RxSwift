//
//  Empty.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/30/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    /**
     Returns an empty observable sequence, using the specified scheduler to send out the single `Completed` message.

     - seealso: [empty operator on reactivex.io](http://reactivex.io/documentation/operators/empty-never-throw.html)

     - returns: An observable sequence with no elements.
     */
    /*
     类方法, 返回实际的逻辑对象, 是一个经常使用的办法.
     类方法, 是一个工厂, 返回一个抽象数据类型, 根据类方法的名称不同, 返回不同的实际对象.
     */
    public static func empty() -> Observable<Element> {
        EmptyProducer<Element>()
    }
}

// 这里就没有什么
final private class EmptyProducer<Element>: Producer<Element> {
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        observer.on(.completed)
        return Disposables.create()
    }
}
