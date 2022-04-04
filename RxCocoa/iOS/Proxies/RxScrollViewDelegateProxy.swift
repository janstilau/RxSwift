//
//  RxScrollViewDelegateProxy.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 6/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(iOS) || os(tvOS)

import RxSwift
import UIKit

extension UIScrollView: HasDelegate {
    public typealias Delegate = UIScrollViewDelegate
}

/*
 DelegateProxy 的责任是, 它利用了方法转发机制, 来真正的实现 Publisher 的触发.
 DelegateProxyType 则是 来完成 Publisher 的创建, 和原有 delegate 的维护.
 */

/// For more information take a look at `DelegateProxyType`.
/*
 DelegateProxy<UIScrollView, UIScrollViewDelegate> 有着类型锁定的含义在里面.  这样一些, ParentObject 就是 UIScrollView, DelegateObject 就是 UIScrollViewDelegate 了.
 */
open class RxScrollViewDelegateProxy
: DelegateProxy<UIScrollView, UIScrollViewDelegate>
, DelegateProxyType {
    
    /// Typed parent object.
    public weak private(set) var scrollView: UIScrollView?
    
    /// - parameter scrollView: Parent object for delegate proxy.
    public init(scrollView: ParentObject) {
        self.scrollView = scrollView
        super.init(parentObject: scrollView,
                   delegateProxy: RxScrollViewDelegateProxy.self)
    }
    
    // Register known implementations
    public static func registerKnownImplementations() {
        
        /*
         如果, 传入的是 ScrollView, 那么创建的 delegate 就是 RxScrollViewDelegateProxy 对象.
         如果, 传入的是 UITableView, 那么创建的 delegate 就是 RxTableViewDelegateProxy 对象.
         这是想要实现的效果.
         */
        self.register { RxScrollViewDelegateProxy(scrollView: $0) }
        self.register { RxTableViewDelegateProxy(tableView: $0) }
        self.register { RxCollectionViewDelegateProxy(collectionView: $0) }
        self.register { RxTextViewDelegateProxy(textView: $0) }
    }
    
    // 发射信号, 带有当前的 Offset 值.
    private var _contentOffsetBehaviorSubject: BehaviorSubject<CGPoint>?
    // 发射信号, 仅仅代表着有偏移了.
    private var _contentOffsetPublishSubject: PublishSubject<()>?
    
    // 这个并不对外公布, 在 UIScrollView + rx 中使用了, 当做一个 Publisher.
    internal var contentOffsetBehaviorSubject: BehaviorSubject<CGPoint> {
        if let subject = _contentOffsetBehaviorSubject {
            return subject
        }
        
        let subject = BehaviorSubject<CGPoint>(value: self.scrollView?.contentOffset ?? CGPoint.zero)
        _contentOffsetBehaviorSubject = subject
        
        return subject
    }
    
    /// Optimized version used for observing content offset changes.
    internal var contentOffsetPublishSubject: PublishSubject<()> {
        if let subject = _contentOffsetPublishSubject {
            return subject
        }
        
        let subject = PublishSubject<()>()
        _contentOffsetPublishSubject = subject
        
        return subject
    }
    
    deinit {
        if let subject = _contentOffsetBehaviorSubject {
            subject.on(.completed)
        }
        
        if let subject = _contentOffsetPublishSubject {
            subject.on(.completed)
        }
    }
}

extension RxScrollViewDelegateProxy: UIScrollViewDelegate {
    
    /*
     DelegateProxy 里面, 讲的很清楚. 对于需要返回值的信号来说, 需要自己去定义 subject 来保证值的正确.
     所以, 这里就定义了 _contentOffsetBehaviorSubject, _contentOffsetPublishSubject 来确保信号中值的正确.
     同时, 因为 RxScrollViewDelegateProxy 实现了 scrollViewDidScroll, 他就不会在走 forwardInvocation 机制了. 那么就需要手动的调用, _forwardToDelegate 来保证存储的 _forwardToDelegate 能够正常的处理. 
     */
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let subject = _contentOffsetBehaviorSubject {
            subject.on(.next(scrollView.contentOffset))
        }
        if let subject = _contentOffsetPublishSubject {
            subject.on(.next(()))
        }
        self._forwardToDelegate?.scrollViewDidScroll?(scrollView)
    }
}

#endif
