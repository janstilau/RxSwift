//
//  ObservableType+PrimitiveSequence.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/17/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    /*
     The `asSingle` operator throws a `RxError.noElements` or `RxError.moreThanOneElement`
     if the source Observable does not emit exactly one element before successfully completing.
     */
    public func asSingle() -> Single<Element> {
        PrimitiveSequence(raw: AsSingle(source: self.asObservable()))
    }
    
    /*
     The `first` operator emits only the very first item emitted by this Observable,
     or nil if this Observable completes without emitting anything.
     */
    public func first() -> Single<Element?> {
        PrimitiveSequence(raw: First(source: self.asObservable()))
    }

    /**
     The `asMaybe` operator throws a `RxError.moreThanOneElement`
     if the source Observable does not emit at most one element before successfully completing.
     */
    public func asMaybe() -> Maybe<Element> {
        PrimitiveSequence(raw: AsMaybe(source: self.asObservable()))
    }
}

extension ObservableType where Element == Never {
    /**
     - returns: An observable sequence that completes.
     */
    public func asCompletable()
        -> Completable {
            return PrimitiveSequence(raw: self.asObservable())
    }
}
