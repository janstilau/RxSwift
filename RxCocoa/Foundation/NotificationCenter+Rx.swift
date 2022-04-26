//
//  NotificationCenter+Rx.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 5/2/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation
import RxSwift

extension Reactive where Base: NotificationCenter {
    /*
    Transforms notifications posted to notification center to observable sequence of notifications.
    */
    public func notification(_ name: Notification.Name?, object: AnyObject? = nil) -> Observable<Notification> {
        /*
         可以想象的是, 在 NotificationCenter 内部, 一定是创建了一个对象, 包装了传输过来的 Block, 然后在 NotificationCenter 内部, 存储了这个对象.
         这样, 每次 name Notification 发出的时候, 找到这个对象然后调用存储的 Block.
         和通过 Object, SEL 来触发没有太大的区别.
         
         如何删除这个对象, 就是使用返回的句柄.
         
         rx 使用了这个机制, 在 NotificationCenter 上增加扩展, Observable.create 创建了一个 AnonymousObservableSink, 这个对象是响应链条的头.
         当, 触发了信号发送的时候, 这个 Sink 接受到信号, 然后传递到后方的节点上.
         现在, 触发信号发送的时机, 是 NotificationCenter post 的时候. 
         */
        
        // 相比较 Combine 里面的实现, 这里的实现, 简单清晰太多了. 
        return Observable.create { [weak object] observer in
            let nsObserver = self.base.addObserver(forName: name, object: object, queue: nil) { notification in
                observer.on(.next(notification))
            }
            
            return Disposables.create {
                self.base.removeObserver(nsObserver)
            }
        }
    }
}
