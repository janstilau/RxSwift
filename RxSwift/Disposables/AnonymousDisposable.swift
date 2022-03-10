

// Anonymous 的实现, 就是在里面存储一个闭包.
// Swift 直接传对象方法, 可以保存那个对象的生命周期. 所以, 不用像之前 OC 那样包装一层.

private final class AnonymousDisposable : DisposeBase, Cancelable {
    public typealias DisposeAction = () -> Void
    
    private let disposed = AtomicInt(0) // 一个状态位置, 标明自己已经 Disposed 过了.
    private var disposeAction: DisposeAction? // 当 Dispose 实际发生的时候, 应该执行的方法.
    
    /// - returns: Was resource disposed.
    public var isDisposed: Bool {
        isFlagSet(self.disposed, 1)
    }
    
    private init(_ disposeAction: @escaping DisposeAction) {
        self.disposeAction = disposeAction
        super.init()
    }
    
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
            // fetchOr 的设计, 确保了, 只会进行一次的 Action 的触发. 
            if let action = self.disposeAction {
                self.disposeAction = nil
                action()
            }
        }
    }
}

extension Disposables {
    
    // 这里, 传递过来的动作是, 当被 dispose 的时候, 应该执行的动作.
    public static func create(with dispose: @escaping () -> Void) -> Cancelable {
        AnonymousDisposable(disposeAction: dispose)
    }
    
}
