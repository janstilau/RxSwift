//
//  AnonymousObserver.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 Swift 里面, 各种 Anonymous 开头的类, 一般都有一个通用的设计思路.
 就是定义一个闭包, 然后使用这个闭包, 来实现对应的 Protocol 要求的功能.
 */

// 这是一个非常非常重要的一个类.
// 这是从响应式的世界, 到达命令式世界的桥梁.
// 已经分析出来了, 其实会有一个 Sink 对象串联出来的响应链条. 那么最后的节点, 其实就是这个 AnonymousObserver 对象.
// subscribe 函数, 最终会生成这样的一个对象, 作为指令式的世界, 在响应式世界的插入点. 
final class AnonymousObserver<Element>: ObserverBase<Element> {
    
    typealias EventHandler = (Event<Element>) -> Void
    
    private let eventHandler : EventHandler
    
    init(_ eventHandler: @escaping EventHandler) {
        self.eventHandler = eventHandler
    }
    
    // On 的处理, 就是调用自己的存储的 eventHandler.
    override func onCore(_ event: Event<Element>) {
        self.eventHandler(event)
    }
}
