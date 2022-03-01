//
//  ObserverBase.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 一个简单的对于 ObserverType 的实现.
 内部维护一个 Stopped 的状态, 如果接受到了 Stopped Event, 就将该值进行设置.
 如果是 Next Event, 就判断是否当前已经 Stopped. 如果是, 不进行处理. 
 */
class ObserverBase<Element> : Disposable, ObserverType {
    
    private let isStopped = AtomicInt(0)
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            if load(self.isStopped) == 0 {
                self.onCore(event)
            }
        case .error, .completed:
            if fetchOr(self.isStopped, 1) == 0 {
                self.onCore(event)
            }
        }
    }
    
    func onCore(_ event: Event<Element>) {
        rxAbstractMethod()
    }
    
    // 将自己的 Stopped 状态设置为 true.
    func dispose() {
        fetchOr(self.isStopped, 1)
    }
}
