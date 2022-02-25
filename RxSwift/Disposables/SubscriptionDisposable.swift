
// 这里, 使用了 SynchronizedUnsubscribeType 这层接口, 将 Subject 的实际类型进行了隐藏.
struct SubscriptionDisposable<T: SynchronizedUnsubscribeType> : Disposable {
    private let key: T.DisposeKey
    private weak var owner: T?
    
    init(owner: T, key: T.DisposeKey) {
        self.owner = owner
        self.key = key
    }
    
    func dispose() {
        // 在 Subject 的 Subscription 里面, 调用这个方法, 取消注册.
        self.owner?.synchronizedUnsubscribe(self.key)
    }
}
