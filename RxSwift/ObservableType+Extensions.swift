//
//  ObservableType+Extensions.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if DEBUG
import Foundation
#endif

/*
 这是一座桥梁.
 可以将响应式的 Publisher 链式代码, 终结并且桥接到指令式的世界里面来.
 */
extension ObservableType {
    
    public func subscribe(_ on: @escaping (Event<Element>) -> Void) -> Disposable {
        let observer = AnonymousObserver { e in
            on(e)
        }
        return self.asObservable().subscribe(observer)
    }
    
    // 没有看到过这样的用法, object 作为了信号的附加数据, 在每一个时间处理中被传递.
    public func subscribe<Object: AnyObject>(
        with object: Object,
        onNext: ((Object, Element) -> Void)? = nil,
        onError: ((Object, Swift.Error) -> Void)? = nil,
        onCompleted: ((Object) -> Void)? = nil,
        onDisposed: ((Object) -> Void)? = nil
    ) -> Disposable {
        subscribe(
            onNext: { [weak object] in
                guard let object = object else { return }
                onNext?(object, $0)
            },
            onError: { [weak object] in
                guard let object = object else { return }
                onError?(object, $0)
            },
            onCompleted: { [weak object] in
                guard let object = object else { return }
                onCompleted?(object)
            },
            onDisposed: { [weak object] in
                guard let object = object else { return }
                onDisposed?(object)
            }
        )
    }
    
    /*
     实际上, 经常使用的方法.
     */
    public func subscribe(
        onNext: ((Element) -> Void)? = nil,
        onError: ((Swift.Error) -> Void)? = nil,
        onCompleted: (() -> Void)? = nil,
        onDisposed: (() -> Void)? = nil
    ) -> Disposable {
        let disposable: Disposable
        
        if let disposed = onDisposed {
            disposable = Disposables.create(with: disposed)
        } else {
            disposable = Disposables.create()
        }
        
        /*
         将以上传递过来的各种闭包, 包装到了 AnonymousObserver 的 event 处理闭包里面了.
         然后, 将 AnonymousObserver 注册到信号处理中.
         */
        let observer = AnonymousObserver<Element> { event in
            switch event {
            case .next(let value):
                onNext?(value)
            case .error(let error):
                if let onError = onError {
                    onError(error)
                } else {
                }
                disposable.dispose()
            case .completed:
                onCompleted?()
                disposable.dispose()
            }
        }
        
        // disposable 是用来触发, 额外的用户传入的 dispose 事件的响应.
        return Disposables.create( self.asObservable().subscribe(observer), disposable )
    }
}



import Foundation

extension Hooks {
    public typealias DefaultErrorHandler = (_ subscriptionCallStack: [String], _ error: Error) -> Void
    public typealias CustomCaptureSubscriptionCallstack = () -> [String]
    
    private static let lock = RecursiveLock()
    private static var _defaultErrorHandler: DefaultErrorHandler = { subscriptionCallStack, error in
#if DEBUG
        let serializedCallStack = subscriptionCallStack.joined(separator: "\n")
        print("Unhandled error happened: \(error)")
        if !serializedCallStack.isEmpty {
            print("subscription called from:\n\(serializedCallStack)")
        }
#endif
    }
    private static var _customCaptureSubscriptionCallstack: CustomCaptureSubscriptionCallstack = {
#if DEBUG
        return Thread.callStackSymbols
#else
        return []
#endif
    }
    
    /// Error handler called in case onError handler wasn't provided.
    public static var defaultErrorHandler: DefaultErrorHandler {
        get {
            lock.performLocked { _defaultErrorHandler }
        }
        set {
            lock.performLocked { _defaultErrorHandler = newValue }
        }
    }
    
    /// Subscription callstack block to fetch custom callstack information.
    public static var customCaptureSubscriptionCallstack: CustomCaptureSubscriptionCallstack {
        get {
            lock.performLocked { _customCaptureSubscriptionCallstack }
        }
        set {
            lock.performLocked { _customCaptureSubscriptionCallstack = newValue }
        }
    }
}

