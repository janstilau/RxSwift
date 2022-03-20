//
//  ControlTarget.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 2/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(iOS) || os(tvOS) || os(macOS)

import RxSwift

#if os(iOS) || os(tvOS)
import UIKit

typealias Control = UIKit.UIControl
#elseif os(macOS)
import Cocoa

typealias Control = Cocoa.NSControl
#endif

// RXTarget 有着自我引用的生命周期管理.
final class ControlTarget: RxTarget {
    typealias Callback = (Control) -> Void
    
    let selector: Selector = #selector(ControlTarget.eventHandler(_:))
    
    weak var control: Control?
#if os(iOS) || os(tvOS)
    let controlEvents: UIControl.Event
#endif
    
    var callback: Callback?
    
#if os(iOS) || os(tvOS)
    init(control: Control, controlEvents: UIControl.Event, callback: @escaping Callback) {
        self.control = control
        self.controlEvents = controlEvents
        self.callback = callback
        
        super.init()
        
        // 在构建方法里面, 进行了 target action 的监听.
        control.addTarget(self, action: selector, for: controlEvents)
    }
#endif
    
    // 然后在 Control 的 Event 触发的时候, 进行 CallBack 的调用,
    // 这在自己的公司的代码工具库里面, 也经常使用.
    @objc func eventHandler(_ sender: Control!) {
        if let callback = self.callback,
           let control = self.control {
            callback(control)
        }
    }
    
    override func dispose() {
        super.dispose()
        // 在 dispose 的时候, 解除 target action 的监听状态.
        self.control?.removeTarget(self, action: self.selector, for: self.controlEvents)
        self.callback = nil
    }
}

#endif
