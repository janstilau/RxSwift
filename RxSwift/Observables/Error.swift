//
//  Error.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/30/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    /*
     Returns an observable sequence that terminates with an `error`.
     */
    public static func error(_ error: Swift.Error) -> Observable<Element> {
        ErrorProducer(error: error)
    }
}

final private class ErrorProducer<Element>: Producer<Element> {
    private let error: Swift.Error
    
    init(error: Swift.Error) {
        self.error = error
    }
    
    // 在注册的时候, 直接就是一个 error.
    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        observer.on(.error(self.error))
        return Disposables.create()
    }
}
