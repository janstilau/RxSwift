//
//  BehaviorRelay.swift
//  RxRelay
//
//  Created by Krunoslav Zaher on 10/7/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxSwift

/// BehaviorRelay is a wrapper for `BehaviorSubject`.
///
/// Unlike `BehaviorSubject` it can't terminate with error or completed.

// 限制了 BehaviorSubject 的能力, 只能充当 Publisher 了, 提供给了一个输出 value 的方法.
// 实际上, UI 相关的 Publisher, 应该绑定事件到这个上面. 因为 UI 不会发出 Error.
public final class BehaviorRelay<Element>: ObservableType {
    private let subject: BehaviorSubject<Element>
    
    public func accept(_ event: Element) {
        self.subject.onNext(event)
    }
    
    /// Current value of behavior subject
    public var value: Element {
        // this try! is ok because subject can't error out or be disposed
        return try! self.subject.value()
    }
    
    /// Initializes behavior relay with initial value.
    public init(value: Element) {
        self.subject = BehaviorSubject(value: value)
    }
    
    /// Subscribes observer
    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        self.subject.subscribe(observer)
    }
    
    /// - returns: Canonical interface for push style sequence
    public func asObservable() -> Observable<Element> {
        self.subject.asObservable()
    }
}
