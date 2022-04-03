//
//  UIButton+Rx.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 3/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(iOS)

import RxSwift
import UIKit

extension Reactive where Base: UIButton {
    
    /// Reactive wrapper for `TouchUpInside` control event.
    public var tap: ControlEvent<Void> {
        controlEvent(.touchUpInside)
    }
}

#endif


#if os(iOS) || os(tvOS)

import RxSwift
import UIKit

/*
 各种方法, 返回了对象里面, 封装了数据过来之后, 应该执行的逻辑. 
 */
extension Reactive where Base: UIButton {
    
    // Binder 是一个 ObserverType, 所以这是用来赋值的 .
    // _ = Observable.just("normal").subscribe(button.rx.title(for: .normal))
    public func title(for controlState: UIControl.State = []) -> Binder<String?> {
        Binder(self.base) { button, title in
            button.setTitle(title, for: controlState)
        }
    }
    
    /// Reactive wrapper for `setImage(_:for:)`
    public func image(for controlState: UIControl.State = []) -> Binder<UIImage?> {
        Binder(self.base) { button, image in
            button.setImage(image, for: controlState)
        }
    }
    
    /// Reactive wrapper for `setBackgroundImage(_:for:)`
    public func backgroundImage(for controlState: UIControl.State = []) -> Binder<UIImage?> {
        Binder(self.base) { button, image in
            button.setBackgroundImage(image, for: controlState)
        }
    }
    
}
#endif

#if os(iOS) || os(tvOS)
import RxSwift
import UIKit

extension Reactive where Base: UIButton {
    /// Reactive wrapper for `setAttributedTitle(_:controlState:)`
    public func attributedTitle(for controlState: UIControl.State = []) -> Binder<NSAttributedString?> {
        return Binder(self.base) { button, attributedTitle -> Void in
            button.setAttributedTitle(attributedTitle, for: controlState)
        }
    }
}
#endif
