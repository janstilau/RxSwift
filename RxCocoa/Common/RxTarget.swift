//
//  RxTarget.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 7/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

import RxSwift

// 自循环引用的一个对象.
// 只有明确的调用 dispose 的时候, 才会去释放.
// 用 SelfRetain 命名, 应该更加的清晰.

/*
 这种, 需要明确的调用一个函数, 来触发停止的操作. 其实也是正常的.
 比如, socket 通信, 必须显式的调用 disconnect 才可以.
 当然, 如果按照面向对象的理论, 在析构函数里面, 也应该增加 disconnect 的调用. 但是如果还需要专门找一个强引用, 会让代码复杂. 例如, NotificationCetner 里面, 使用 Block 添加回调, 那个对象其实就是在 Center 的内部的, 需要明确的使用 remove 操作, 才能完成取消注册的动作. 
 */
// 转移到 Gesture 里面. 
//class RxTarget : NSObject, Disposable {
//
//    private var retainSelf: RxTarget?
//
//    override init() {
//        super.init()
//        self.retainSelf = self
//    }
//
//    func dispose() {
//        self.retainSelf = nil
//    }
//}
