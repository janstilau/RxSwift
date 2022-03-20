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
open class RxScrollViewDelegateProxy
: DelegateProxy<UIScrollView, UIScrollViewDelegate>
, DelegateProxyType {
    
    /// Typed parent object.
    public weak private(set) var scrollView: UIScrollView?
    
    /// - parameter scrollView: Parent object for delegate proxy.
    public init(scrollView: ParentObject) {
        self.scrollView = scrollView
        super.init(parentObject: scrollView, delegateProxy: RxScrollViewDelegateProxy.self)
    }
    
    // Register known implementations
    public static func registerKnownImplementations() {
        
        self.register { RxScrollViewDelegateProxy(scrollView: $0) }
        self.register { RxTableViewDelegateProxy(tableView: $0) }
        self.register { RxCollectionViewDelegateProxy(collectionView: $0) }
        self.register { RxTextViewDelegateProxy(textView: $0) }
    }
    
    // 发射信号, 带有当前的 Offset 值.
    private var _contentOffsetBehaviorSubject: BehaviorSubject<CGPoint>?
    // 发射信号, 仅仅代表着有偏移了.
    private var _contentOffsetPublishSubject: PublishSubject<()>?
    
    // 懒加载的机制.
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
    
    // 对于, 一些常用到的代理方法, 还是要在 RxScrollViewDelegateProxy 中实现.
    // 这样就不会走到最后的方法转发的阶段. 可以提高效率.
    // 在自己的实现里面, 主动触发自己维护的 Publisher 对象的 on 
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
