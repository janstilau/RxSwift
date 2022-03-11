//
//  StartWith.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/6/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    
    // 可以在信号中, 插入一些已有的数据. 
    public func startWith(_ elements: Element ...)
    -> Observable<Element> {
        return StartWith(source: self.asObservable(), elements: elements)
    }
}

final private class StartWith<Element>: Producer<Element> {
    let elements: [Element]
    let source: Observable<Element>
    
    init(source: Observable<Element>, elements: [Element]) {
        self.source = source
        self.elements = elements
        super.init()
    }
    
    //
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        // 直接将存储的数据, 传递给后方.
        for e in self.elements {
            observer.on(.next(e))
        }
        // 直接让 source subscribe 存储的后方节点.
        return (sink: Disposables.create(), subscription: self.source.subscribe(observer))
    }
}
