//
//  ObservableConvertibleType+Driver.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 9/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift

extension ObservableConvertibleType {
    /**
    Converts observable sequence to `Driver` trait.
    
    - parameter onErrorJustReturn: Element to return in case of error and after that complete the sequence.
    - returns: Driver trait.
    */
    public func asDriver(onErrorJustReturn: Element) -> Driver<Element> {
        let source = self
            .asObservable()
        // 一定要在 DriverSharingStrategy 指定的调度器上, 进行数据的处理.
            .observe(on:DriverSharingStrategy.scheduler)
            .catchAndReturn(onErrorJustReturn)
        return Driver(source)
    }
    
    /**
    Converts observable sequence to `Driver` trait.
    
    - parameter onErrorDriveWith: Driver that continues to drive the sequence in case of error.
    - returns: Driver trait.
    */
    public func asDriver(onErrorDriveWith: Driver<Element>) -> Driver<Element> {
        let source = self
            .asObservable()
            .observe(on:DriverSharingStrategy.scheduler)
            .catch { _ in
                onErrorDriveWith.asObservable()
            }
        return Driver(source)
    }

    /*
    Converts observable sequence to `Driver` trait.
    */
    public func asDriver(onErrorRecover: @escaping (_ error: Swift.Error) -> Driver<Element>) -> Driver<Element> {
        let source = self
            .asObservable()
        // 主动的进行了主线程的切换.
            .observe(on:DriverSharingStrategy.scheduler)
            .catch { error in
                onErrorRecover(error).asObservable()
            }
        return Driver(source)
    }
}
