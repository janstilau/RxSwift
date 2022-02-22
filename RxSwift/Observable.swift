//
//  Observable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 
 */
/// A type-erased `ObservableType`. 
///
/// It represents a push style sequence.
public class Observable<Element> : ObservableType {
    init() {
        _ = Resources.incrementTotal()
    }
    deinit {
        _ = Resources.decrementTotal()
    }
    
    // func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element
    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        rxAbstractMethod()
    }
    
    public func asObservable() -> Observable<Element> { self }
}

