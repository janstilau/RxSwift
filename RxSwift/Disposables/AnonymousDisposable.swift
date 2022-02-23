//
//  AnonymousDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents an Action-based disposable.
///
/// When dispose method is called, disposal action will be dereferenced.
private final class AnonymousDisposable : DisposeBase, Cancelable {
    public typealias DisposeAction = () -> Void
    
    private let disposed = AtomicInt(0) // 一个状态位置, 标明自己已经 Disposed 过了.
    private var disposeAction: DisposeAction? // 当 Dispose 实际发生的时候, 应该执行的方法.
    
    /// - returns: Was resource disposed.
    public var isDisposed: Bool {
        isFlagSet(self.disposed, 1)
    }
    
    /// Constructs a new disposable with the given action used for disposal.
    ///
    /// - parameter disposeAction: Disposal action which will be run upon calling `dispose`.
    private init(_ disposeAction: @escaping DisposeAction) {
        self.disposeAction = disposeAction
        super.init()
    }
    
    // Non-deprecated version of the constructor, used by `Disposables.create(with:)`
    fileprivate init(disposeAction: @escaping DisposeAction) {
        self.disposeAction = disposeAction
        super.init()
    }
    
    /// Calls the disposal action if and only if the current instance hasn't been disposed yet.
    ///
    /// After invoking disposal action, disposal action will be dereferenced.
    fileprivate func dispose() {
        // FetchOr 会在线程安全的情况下, 设置新值, 返回旧值
        // 只有旧值为 0 的情况下, 才会执行之前存储的 disposeAction 内的逻辑.
        if fetchOr(self.disposed, 1) == 0 {
            if let action = self.disposeAction {
                self.disposeAction = nil
                action()
            }
        }
    }
}

extension Disposables {
    
    /// Constructs a new disposable with the given action used for disposal.
    ///
    /// - parameter dispose: Disposal action which will be run upon calling `dispose`.
    // 这里, 传递过来的动作是, 当被 dispose 的时候, 应该执行的动作.
    public static func create(with dispose: @escaping () -> Void) -> Cancelable {
        AnonymousDisposable(disposeAction: dispose)
    }
    
}
