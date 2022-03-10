
// 很简单的意见事情, 但是还是要用一个盒子来进行包装.
// 因为, 实际用到流程里面的, 不是具体的类型, 而是一个抽象数据类型, 就是 Cancelable. 所以, 使用盒子装起来, 然后在接口函数里面, 完成盒子里面数据的 dispose .
private final class BinaryDisposable : DisposeBase, Cancelable {
    
    private let disposed = AtomicInt(0)
    
    // state
    private var disposable1: Disposable?
    private var disposable2: Disposable?
    
    /// - returns: Was resource disposed.
    var isDisposed: Bool {
        isFlagSet(self.disposed, 1)
    }
    
    init(_ disposable1: Disposable, _ disposable2: Disposable) {
        self.disposable1 = disposable1
        self.disposable2 = disposable2
        super.init()
    }
    
    // 这个盒子, 实现
    func dispose() {
        if fetchOr(self.disposed, 1) == 0 {
            self.disposable1?.dispose()
            self.disposable2?.dispose()
            self.disposable1 = nil
            self.disposable2 = nil
        }
    }
}

extension Disposables {
    
    /// Creates a disposable with the given disposables.
    public static func create(_ disposable1: Disposable, _ disposable2: Disposable) -> Cancelable {
        BinaryDisposable(disposable1, disposable2)
    }
    
}
