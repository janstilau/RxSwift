//
//  ObservableConvertibleType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/17/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 可以转化成为一个 Observable 的抽象.
 各种 Traits 对象, 并不是 Observable 对象, 而是 ObservableConvertibleType 对象.
 
 这挺重要的, 这些 Traits 提供了更好, 更符合自己场景的接口, 但是还是要纳入到 Pinpline 体系的. 始终 asObservable 可以让流程顺利的走下去. 
 */
public protocol ObservableConvertibleType {
    
    associatedtype Element
    func asObservable() -> Observable<Element>
}
