//
//  ObservableConvertibleType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/17/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// 这个类型, 是可以变为一个 Publisher.
// 例如 ContropProperty, 就是将自己的 Sink 返回.
public protocol ObservableConvertibleType {
    
    associatedtype Element
    func asObservable() -> Observable<Element>
}
