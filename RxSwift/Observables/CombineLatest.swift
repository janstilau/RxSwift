
/*
 在 CombineLatestObserver 中, 没有直接引用 CombineLatestSink, 而是引用了一个 CombineLatestProtocol 对象.
 */
protocol CombineLatestProtocol: AnyObject {
    func next(_ index: Int)
    func fail(_ error: Swift.Error)
    func done(_ index: Int)
}

/*
 CombineLatestSink 内部会创建多个 CombineLatestObserver, 这些 CombineLatestObserver 是真正的 Publisher 的监听者.
 CombineLatestObserver 的 on 操作, 会调用 CombineLatestSink 的 next, fail, done 方法, 通过 CombineLatestProtocol 指定的协议.
 CombineLatestSink 会在 next, fail, done 内部维护自己的状态, 然后根据结果, 判断应该给后续节点发送什么样的信号.
 */

/*
 如果, 我们自己去写, 可能就是一个 check 函数, 里面进行所有的状态判断, 如果都有值了, 就进行后续操作.
 然后, 每个异步操作的最后, 都进行这个 check 函数.
 */
class CombineLatestSink<Observer: ObserverType> : Sink<Observer> , CombineLatestProtocol {
        
    // 在 RX 里面, 使用了大量的 typealias
    typealias Element = Observer.Element
    // 这个值, 是被共享的. Sink 生成的每个 CombineLatestObserver 都使用了同样的一个 lock. 这样保证了线程安全. 
    let lock = RecursiveLock()
    
    // arity 参数的个数.
    private let arity: Int
    private var numberOfValues = 0 // 这个代表着, 当前有多少个 CombineLatestObserver 已经接收到了数据.
    private var numberOfDone = 0 // 这个代表着, 当前有多少个 CombineLatestObserver 已经接收到了 Complete 事件.
    private var hasValue: [Bool] // 每个 CombineLatestObserver 的状态记录
    private var isDone: [Bool] // 每个 CombineLatestObserver 的状态记录.
    
    /*
     从以上的实现可以看到, 同我们自己写一个 Check 函数的实现, 没有任何的区别.
     rx 将这些逻辑, 都封装起来变为一个个的可组装的节点, 使用这些节点, 可以大大的减轻逻辑的复杂度.
     
     不过, 使用这些节点的前提, 是需要明确的记忆各个方法的作用是什么, 如果能够知道实现原理, 更加会对代码胸有成竹.
     */
    
    init(arity: Int, observer: Observer, cancel: Cancelable) {
        /*
         arity 就代表着, 当前有多少个需要被 Combine 的 Publisher. 每种 Publisher 的当前状态, 使用一个数组来进行记录.
         数组很好, 能够快速的定位. 天然带有 key 值.
         */
        self.arity = arity
        self.hasValue = [Bool](repeating: false, count: arity)
        self.isDone = [Bool](repeating: false, count: arity)
        super.init(observer: observer, cancel: cancel)
    }
    
    /*
     当所有的 CombineLatestObserver 都有了值之后, 调用该方法, 使用每个 CombineLatestObserver 的最新值, 来计算出要给之后节点发送的值.
     */
    func getResult() throws -> Element {
        rxAbstractMethod()
    }
    
    // 被调用的时候, 处于线程安全的状态.
    func next(_ index: Int) {
        // 如果, 之间这个位置没有值, 就将这个位置设置为 true, 然后记录下填空了的数据个数.
        if !self.hasValue[index] {
            self.hasValue[index] = true
            self.numberOfValues += 1
        }
        
        // 如果, 都有了值了, 就可以触发 getResult, 然后将结果, 发送给后续的节点了.
        if self.numberOfValues == self.arity {
            do {
                let result = try self.getResult()
                // getResult 会将存储的 ele 传入进行变化, 得到最终结果, 将最终结果当做 next 传出.
                self.forwardOn(.next(result))
            } catch let e {
                self.forwardOn(.error(e))
                self.dispose()
            }
        } else {
            // 没太理解, 为什么会到这里.
            var allOthersDone = true
            
            for i in 0 ..< self.arity {
                if i != index && !self.isDone[i] {
                    allOthersDone = false
                    break
                }
            }
            
            if allOthersDone {
                self.forwardOn(.completed)
                self.dispose()
            }
        }
    }
    
    // 只要有一个是 error, 整个 combineLast 进行 dispose.
    func fail(_ error: Swift.Error) {
        self.forwardOn(.error(error))
        self.dispose()
    }
    
    // complete 的 element 会被记录起来, 只有三个都 compelte 了之后, 才会 forward complete 的事件
    func done(_ index: Int) {
        if self.isDone[index] {
            return
        }
        
        // 记录已经 complete 的元素的位置.
        self.isDone[index] = true
        self.numberOfDone += 1
        
        // 如果都 compelte, 才会进行整个 combineLast 的 forward 的信号发送.
        if self.numberOfDone == self.arity {
            self.forwardOn(.completed)
            self.dispose()
        }
    }
}

/*
 
 */
final class CombineLatestObserver<Element>
: ObserverType
, LockOwnerType
, SynchronizedOnType {
    
    typealias ValueSetter = (Element) -> Void
    
    private let parent: CombineLatestProtocol
    
    let lock: RecursiveLock // 这把锁, 是 Snik 下每个 CombineLatestObserver 公用的.
    private let index: Int // Sink 维护着, 每个 CombineLatestObserver 的 Index 值.
    private let this: Disposable //
    private let setLatestValue: ValueSetter
    
    init(lock: RecursiveLock, parent: CombineLatestProtocol, index: Int, setLatestValue: @escaping ValueSetter, this: Disposable) {
        self.lock = lock
        self.parent = parent
        self.index = index
        self.this = this
        self.setLatestValue = setLatestValue
    }
    
    func on(_ event: Event<Element>) {
        self.synchronizedOn(event)
    }
    
    // 在 CombineLatestObserver 的事件处理逻辑中, 除了记录最新的值外, 还要通知上层, 做相应的状态记录.
    func synchronized_on(_ event: Event<Element>) {
        switch event {
        case .next(let value):
            self.setLatestValue(value)
            self.parent.next(self.index)
        case .error(let error):
            self.this.dispose()
            self.parent.fail(error)
        case .completed:
            self.this.dispose()
            self.parent.done(self.index)
        }
    }
}
