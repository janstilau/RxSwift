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
class RxTarget : NSObject
               , Disposable {
    
    private var retainSelf: RxTarget?
    
    override init() {
        super.init()
        self.retainSelf = self

#if DEBUG
        MainScheduler.ensureRunningOnMainThread()
#endif
    }
    
    func dispose() {
        self.retainSelf = nil
    }
}
