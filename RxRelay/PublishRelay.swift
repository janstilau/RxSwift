//
//  PublishRelay.swift
//  RxRelay
//
//  Created by Krunoslav Zaher on 3/28/15.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxSwift

// 相当于, 限制了 PublishSubject 的能力.
// 只能充当 ObservableType 了, 只能是通过 accept 来获取 next 的信号, 然后通知到后方节点.
// PublishRelay 不能充当 Observer 了.
public final class PublishRelay<Element>: ObservableType {
    private let subject: PublishSubject<Element>
    
    // Accepts `event` and emits it to subscribers
    // Accept, 就是 Subject 的改值操作. 在 Varibale 的实现里面, 也即是使用 didSet 进行 onNext 的发送.
    public func accept(_ event: Element) {
        self.subject.onNext(event)
    }
    
    public init() {
        self.subject = PublishSubject()
    }

    // ObservableType 的实现, 就是把 Observer 填充到 subject 的 Bag 里面. 
    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.subject.subscribe(observer)
    }
    
    /// - returns: Canonical interface for push style sequence
    public func asObservable() -> Observable<Element> {
        self.subject.asObservable()
    }
}
