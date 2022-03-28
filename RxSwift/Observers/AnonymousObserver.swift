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
