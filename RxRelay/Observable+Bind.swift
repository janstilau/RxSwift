//
//  Observable+Bind.swift
//  RxRelay
//
//  Created by Shai Mishali on 09/04/2019.
//  Copyright © 2019 Krunoslav Zaher. All rights reserved.
//

import RxSwift


/*
 各种 Bind 到 SubjectRelay, 就是使用一个 AnonymousObserver, 包装 Relay 的 accept 方法的调用 .
 
 Replay 保证, 是不应该接收到结束事件的. 所以, 它并不是一个 Observer.
 想要使用它, 只能使用 accept.
 而想要纳入到响应式的链式代码中, 只能使用 bindto 函数.
 在这个函数内部, 包装了一个 AnonymousObserver 调用 relay 的 accept 函数, 而面的结束事件, 不做处理. 
 */
extension ObservableType {
    /*
     Creates new subscription and sends elements to publish relay(s).
     */
    // PublishRelay 已经失去了 Observer 的能力了, 所以不能直接被 subscribe.
    public func bind(to relays: PublishRelay<Element>...) -> Disposable {
        bind(to: relays)
    }
    
    /**
     Creates new subscription and sends elements to publish relay(s).
     
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     
     - parameter relays: Target publish relays for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    // 自己的 Element 可以可 PublishRelay 的不一样, 每次 ON 之后, 进行一次 Transfrom.
    public func bind(to relays: PublishRelay<Element?>...) -> Disposable {
        self.map { $0 as Element? }.bind(to: relays)
    }
    
    /*
     Creates new subscription and sends elements to publish relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     */
    // Relay 不能当做是 Observer 了, 所以, 上游节点其实是注册给  AnonymousObserver 了.
    // 然后在 AnonymousObserver 中, 根据 event, 调用 relay 的 accept 方法.
    // 因为, Relay 不是一个 Observer, 所以, 只能通过 Bind 才能完成数据流的流动.
    private func bind(to relays: [PublishRelay<Element>]) -> Disposable {
        subscribe { e in
            switch e {
            case let .next(element):
                relays.forEach {
                    $0.accept(element)
                }
            case let .error(error):
                rxFatalErrorInDebug("Binding error to publish relay: \(error)")
            case .completed:
                break
            }
        }
    }
    
    /**
     Creates new subscription and sends elements to behavior relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter relays: Target behavior relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    public func bind(to relays: BehaviorRelay<Element>...) -> Disposable {
        self.bind(to: relays)
    }
    
    /**
     Creates new subscription and sends elements to behavior relay(s).
     
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     
     - parameter relays: Target behavior relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    public func bind(to relays: BehaviorRelay<Element?>...) -> Disposable {
        self.map { $0 as Element? }.bind(to: relays)
    }
    
    /**
     Creates new subscription and sends elements to behavior relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter relays: Target behavior relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    private func bind(to relays: [BehaviorRelay<Element>]) -> Disposable {
        subscribe { e in
            switch e {
            case let .next(element):
                relays.forEach {
                    $0.accept(element)
                }
            case let .error(error):
                rxFatalErrorInDebug("Binding error to behavior relay: \(error)")
            case .completed:
                break
            }
        }
    }
    
    /**
     Creates new subscription and sends elements to replay relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter relays: Target replay relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    public func bind(to relays: ReplayRelay<Element>...) -> Disposable {
        self.bind(to: relays)
    }
    
    /**
     Creates new subscription and sends elements to replay relay(s).
     
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     
     - parameter relays: Target replay relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    public func bind(to relays: ReplayRelay<Element?>...) -> Disposable {
        self.map { $0 as Element? }.bind(to: relays)
    }
    
    /**
     Creates new subscription and sends elements to replay relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter relays: Target replay relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    private func bind(to relays: [ReplayRelay<Element>]) -> Disposable {
        subscribe { e in
            switch e {
            case let .next(element):
                relays.forEach {
                    $0.accept(element)
                }
            case let .error(error):
                rxFatalErrorInDebug("Binding error to behavior relay: \(error)")
            case .completed:
                break
            }
        }
    }
}
