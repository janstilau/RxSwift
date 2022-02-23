//
//  CombineLatest.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol CombineLatestProtocol: AnyObject {
    func next(_ index: Int)
    func fail(_ error: Swift.Error)
    func done(_ index: Int)
}

/*
 CombineLatestSink 内部会创建多个 CombineLatestObserver, 这些 CombineLatestObserver 是真正的 Publisher 的监听者.
 CombineLatestObserver 的 on 操作, 会调用 CombineLatestSink 的 next, fail, done 方法.
 CombineLatestSink 会在 next, fail, done 内部维护自己的状态, 然后根据结果, 判断应该给后续节点发送什么样的信号. 
 */

/*
 如果, 我们自己去写, 可能就是一个 check 函数, 里面进行所有的状态判断, 如果都有值了, 就进行后续操作.
 然后, 每个异步操作的最后, 都进行这个 check 函数.
 
 现在, 使用 CombineLatestSink, 将各个异步操作的结果用信号的方式发出.
 chekc 的逻辑在内部进行封装.
 这就像是使用 sequence map, filter 的逻辑已经, 使用这些提供好, 经典的通用的设计模板, 会让书写简洁, 阅读清晰. 
 */
class CombineLatestSink<Observer: ObserverType>
: Sink<Observer> , CombineLatestProtocol {
    typealias Element = Observer.Element
    
    let lock = RecursiveLock()
    
    // arity 参数的个数.
    private let arity: Int
    private var numberOfValues = 0
    private var numberOfDone = 0
    private var hasValue: [Bool]
    private var isDone: [Bool]
    
    init(arity: Int, observer: Observer, cancel: Cancelable) {
        self.arity = arity
        self.hasValue = [Bool](repeating: false, count: arity)
        self.isDone = [Bool](repeating: false, count: arity)
        
        super.init(observer: observer, cancel: cancel)
    }
    
    func getResult() throws -> Element {
        rxAbstractMethod()
    }
    
    func next(_ index: Int) {
        // 如果, 之间这个位置没有值, 就将这个位置设置为 true, 然后记录下填空了的数据个数.
        if !self.hasValue[index] {
            self.hasValue[index] = true
            self.numberOfValues += 1
        }
        
        // 如果, 已经是都有值了.
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

// 这个才是真正的 Observer Type.
final class CombineLatestObserver<Element>
: ObserverType
, LockOwnerType
, SynchronizedOnType {
    typealias ValueSetter = (Element) -> Void
    
    private let parent: CombineLatestProtocol
    
    let lock: RecursiveLock
    private let index: Int
    private let this: Disposable
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
    
    // 自己接收到信号之后, 调用一下记录方法, 然后通知 parent 调用 next 函数.
    // 这已经在线程安全的环境了.
    
    // 各个 Element 的 on, 通知 parent 进行数据的记录, 由 parent 来决定, 是否发送信号, 发送什么信号.
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
