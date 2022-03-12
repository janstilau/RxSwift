//
//  Operators.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 12/6/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import RxCocoa
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// Two way binding operator between control property and relay, that's all it takes.

infix operator <-> : DefaultPrecedence

#if os(iOS)
// 这里, 定义了一个去除中间状态文字的机制.
func nonMarkedText(_ textInput: UITextInput) -> String? {
    let start = textInput.beginningOfDocument
    let end = textInput.endOfDocument

    // 首先, 获取到所有的文字和范围
    guard let rangeAll = textInput.textRange(from: start, to: end),
        let text = textInput.text(in: rangeAll) else {
            return nil
    }

    guard let markedTextRange = textInput.markedTextRange else {
        return text
    }

    // 然后, 获取到 Marked 文字的范围.
    guard let startRange = textInput.textRange(from: start, to: markedTextRange.start),
          let endRange = textInput.textRange(from: markedTextRange.end, to: end) else {
        return text
    }

    // 进行原有的 Text 的截取工作.
    return (textInput.text(in: startRange) ?? "") + (textInput.text(in: endRange) ?? "")
}

// 在这里, 定义了一个操作符. 将 TextInput 的 Text Publisher, 绑定到了 BehaviorRelay 上.
func <-> <Base>(textInput: TextInput<Base>,
                relay: BehaviorRelay<String>) -> Disposable {
    // 这是一个双向绑定.
    // BehaviorRelay 的信号, 会直接绑定到 UI 上. 这其实是 Cocoa 的机制, 直接改变属性值, 不会触发 Event 事件. 所以这里没有循环的触发
    let bindToUIDisposable = relay.bind(to: textInput.text)

    // textInput.text 会是 target action event 触发出的信号, 绑定到 behavior 上. 
    let bindToRelay = textInput.text
        // 可以使用这种方式, 来进行绑定的动作.
        .subscribe(onNext: { [weak base = textInput.base] n in
            guard let base = base else {
                return
            }

            let nonMarkedTextValue = nonMarkedText(base)

            /**
             In some cases `textInput.textRangeFromPosition(start, toPosition: end)` will return nil even though the underlying
             value is not nil. This appears to be an Apple bug. If it's not, and we are doing something wrong, please let us know.
             The can be reproduced easily if replace bottom code with
             
             if nonMarkedTextValue != relay.value {
                relay.accept(nonMarkedTextValue ?? "")
             }

             and you hit "Done" button on keyboard.
             */
            // 这里有一个 Filter 的作用, 重复的数据, 不会添加.
            if let nonMarkedTextValue = nonMarkedTextValue,
               nonMarkedTextValue != relay.value {
                relay.accept(nonMarkedTextValue)
            }
        }, onCompleted:  {
            bindToUIDisposable.dispose()
        })

    return Disposables.create(bindToUIDisposable, bindToRelay)
}
#endif

func <-> <T>(property: ControlProperty<T>, relay: BehaviorRelay<T>) -> Disposable {
    if T.self == String.self {
#if DEBUG && !os(macOS)
        fatalError("It is ok to delete this message, but this is here to warn that you are maybe trying to bind to some `rx.text` property directly to relay.\n" +
            "That will usually work ok, but for some languages that use IME, that simplistic method could cause unexpected issues because it will return intermediate results while text is being inputed.\n" +
            "REMEDY: Just use `textField <-> relay` instead of `textField.rx.text <-> relay`.\n" +
            "Find out more here: https://github.com/ReactiveX/RxSwift/issues/649\n"
            )
#endif
    }

    let bindToUIDisposable = relay.bind(to: property)
    let bindToRelay = property
        .subscribe(onNext: { n in
            relay.accept(n)
        }, onCompleted:  {
            bindToUIDisposable.dispose()
        })

    return Disposables.create(bindToUIDisposable, bindToRelay)
}
