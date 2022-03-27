//
//  SerialDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// Represents a disposable resource whose underlying disposable resource can be replaced by another disposable resource
// causing automatic disposal of the previous underlying disposable resource.

// 在 Catch, FlatMap 里面, 这个会经常使用, 因为这些 Operator 内, 原有的 source 经常会失效, 然后替换一个新的 source.
// 但是外界不应该知道这些, 外界拿到的是一个 subscription, 它仅仅知道的是, 调用 dispose 可以让这个相应链路失效.
// 在这种情况下, 使用 SerialDisposable, 然后在 Operator 内部当 source 失效之后, 使用 SerialDisposable 替换 外界可以触发的 dispose 对象就可以了.
// 存储的 Disposable 可以替换, 每次替换, 自动引起被替换的进行 dispose 的调用.

public final class SerialDisposable : DisposeBase, Cancelable {
    private var lock = SpinLock()
    
    // state
    private var current = nil as Disposable?
    private var disposed = false
    
    public var isDisposed: Bool {
        self.disposed
    }
    
    /// Initializes a new instance of the `SerialDisposable`.
    override public init() {
        super.init()
    }
    
    /*
     Gets or sets the underlying disposable.
     Assigning this property disposes the previous disposable object.
     If the `SerialDisposable` has already been disposed, assignment to this property causes immediate disposal of the given disposable object.
     */
    public var disposable: Disposable {
        get {
            self.lock.performLocked {
                self.current ?? Disposables.create()
            }
        }
        set (newDisposable) {
            // 替换的动作, 是在多线程环境下, 所以进行了保护. 
            let disposable: Disposable? = self.lock.performLocked {
                if self.isDisposed {
                    return newDisposable
                } else {
                    let toDispose = self.current
                    self.current = newDisposable
                    return toDispose
                }
            }
            // 在替换的时候, 原来的要进行 dispose.
            if let disposable = disposable {
                disposable.dispose()
            }
        }
    }
    
    /// Disposes the underlying disposable as well as all future replacements.
    public func dispose() {
        self._dispose()?.dispose()
    }
    
    // 个人非常不喜欢的写法, 为什么在 get 中, 要进行副作用. 
    private func _dispose() -> Disposable? {
        self.lock.performLocked {
            guard !self.isDisposed else { return nil }
            
            self.disposed = true
            let current = self.current
            self.current = nil
            return current
        }
    }
}
