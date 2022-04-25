//
//  SynchronizedUnsubscribeType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// 这个协议, 就是专门做 Subject Type 的注册取消的. 
protocol SynchronizedUnsubscribeType: AnyObject {
    associatedtype DisposeKey
    func synchronizedUnsubscribe(_ disposeKey: DisposeKey)
}
