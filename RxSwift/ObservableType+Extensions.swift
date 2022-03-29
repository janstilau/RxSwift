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
    
    // 提交了一个闭包, 来完成 event 的处理. 将这个闭包存储到 AnonymousObserver 中, 将 AnonymousObserver 对象, 纳入到响应链条里面.
    
    // 这个是响应链条的终点了, 所以, 直接返回了 Disposable
    
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
     使用者, 提供了各个不同的场景应该调用的方法, 但是其实他们都是 event 的 switch 处理分支逻辑.
     所以, 还是构建一个 AnonymousObserver, 将所有的这些分支处理逻辑, 合并到一个 Block 里面.
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
                }
                disposable.dispose()
            case .completed:
                onCompleted?()
                disposable.dispose()
            }
        }
        
        // disposable 是用来触发, 额外的用户传入的 dispose 事件的响应.
        /*
         如果最后是 Map.subscribe.
         self.asObservable().subscribe(observer) 返回的就是 Map 的 SinkDisposer
         里面有 Map 这个 Sink, 一起 Map 的前面节点的 subscribe 的结果 .
         
         所以, subscribe 的返回结果, 是最后一个节点 Sink 对应的 SinkDisposer.
         dispose 的顺序也就是, 最后一个 Sink 的状态改变, 最后一个 Sink 的 Cancel 调用 dispose, 触发前面的一个 Sink 的 Dispose, 链式触发.
         所以, 其实建立节点的过程, 是从后向前. 主动调用 Dispose 触发的顺序, 也是从后向前. 
         */
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

