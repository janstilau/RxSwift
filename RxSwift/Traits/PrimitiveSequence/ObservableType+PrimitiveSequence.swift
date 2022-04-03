//
//  ObservableType+PrimitiveSequence.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/17/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

// asXXX 的构建之后, 然后构建 PrimitiveSequence
// 因为 Single 其实是 PrimitiveSequence 的特化.

// 这几个 Extension 方法, 返回的数据结构都是 PrimitiveSequence
// 因为, 只能是返回这些特殊的数据结构, 才能调用在它上面定义的 SingleEvent 方法.
extension ObservableType {
    /*
     The `asSingle` operator throws a `RxError.noElements` or `RxError.moreThanOneElement`
     if the source Observable does not emit exactly one element before successfully completing.
     */
    public func asSingle() -> Single<Element> {
        // 返回值, 必须是 PrimitiveSequence 这种类型的, 不然没有办法使用 Single 的各种方法.
        // 真正的 Signle 的含义, 是通过 AsSingleSink 实现的. 
        PrimitiveSequence(raw: AsSingle(source: self.asObservable()))
    }
    
    /*
     The `first` operator emits only the very first item emitted by this Observable,
     or nil if this Observable completes without emitting anything.
     */
    // First, 
    public func first() -> Single<Element?> {
        PrimitiveSequence(raw: First(source: self.asObservable()))
    }

    /*
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
