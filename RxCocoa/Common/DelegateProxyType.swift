//
//  DelegateProxyType.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 6/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if !os(Linux)

import Foundation
import RxSwift

/*
 
 `DelegateProxyType` protocol enables using both normal delegates and Rx observable sequences with
 views that can have only one delegate/datasource registered.
 
 `Proxies` store information about observers, subscriptions and delegates
 for specific views.
 
 Type implementing `DelegateProxyType` should never be initialized directly.
 
 To fetch initialized instance of type implementing `DelegateProxyType`, `proxy` method
 should be used.
 
 This is more or less how it works.
 
 
 
 +-------------------------------------------+
 |                                           |
 | UIView subclass (UIScrollView)            |
 |                                           |
 +-----------+-------------------------------+
 |
 | Delegate
 |
 |
 +-----------v-------------------------------+
 |                                           |
 | Delegate proxy : DelegateProxyType        +-----+---->  Observable<T1>
 |                , UIScrollViewDelegate     |     |
 +-----------+-------------------------------+     +---->  Observable<T2>
 |                                     |
 |                                     +---->  Observable<T3>
 |                                     |
 | forwards events                     |
 | to custom delegate                  |
 |                                     v
 +-----------v-------------------------------+
 |                                           |
 | Custom delegate (UIScrollViewDelegate)    |
 |                                           |
 +-------------------------------------------+
 
 
 Since RxCocoa needs to automagically create those Proxies and because views that have delegates can be hierarchical
 
 UITableView : UIScrollView : UIView
 
 .. and corresponding delegates are also hierarchical
 
 UITableViewDelegate : UIScrollViewDelegate : NSObject
 
 ... this mechanism can be extended by using the following snippet in `registerKnownImplementations` or in some other
 part of your app that executes before using `rx.*` (e.g. appDidFinishLaunching).
 
 RxScrollViewDelegateProxy.register { RxTableViewDelegateProxy(parentObject: $0) }
 
 */
public protocol DelegateProxyType: AnyObject {
    
    associatedtype ParentObject: AnyObject
    associatedtype Delegate
    
    /// It is require that enumerate call `register` of the extended DelegateProxy subclasses here.
    static func registerKnownImplementations()
    
    /// Unique identifier for delegate
    static var identifier: UnsafeRawPointer { get }
    
    /// Returns designated delegate property for object.
    ///
    /// Objects can have multiple delegate properties.
    ///
    /// Each delegate property needs to have it's own type implementing `DelegateProxyType`.
    ///
    /// It's abstract method.
    ///
    /// - parameter object: Object that has delegate property.
    /// - returns: Value of delegate property.
    static func currentDelegate(for object: ParentObject) -> Delegate?
    
    /// Sets designated delegate property for object.
    ///
    /// Objects can have multiple delegate properties.
    ///
    /// Each delegate property needs to have it's own type implementing `DelegateProxyType`.
    ///
    /// It's abstract method.
    ///
    /// - parameter delegate: Delegate value.
    /// - parameter object: Object that has delegate property.
    static func setCurrentDelegate(_ delegate: Delegate?, to object: ParentObject)
    
    /// Returns reference of normal delegate that receives all forwarded messages
    /// through `self`.
    ///
    /// - returns: Value of reference if set or nil.
    func forwardToDelegate() -> Delegate?
    
    /// Sets reference of normal delegate that receives all forwarded messages
    /// through `self`.
    ///
    /// - parameter forwardToDelegate: Reference of delegate that receives all messages through `self`.
    /// - parameter retainDelegate: Should `self` retain `forwardToDelegate`.
    func setForwardToDelegate(_ forwardToDelegate: Delegate?, retainDelegate: Bool)
}

// Protocol 的非常好的地方, 就是可以直接在 Extension 里面, 生成全局可用的实现.
extension DelegateProxyType {
    /// Unique identifier for delegate
    public static var identifier: UnsafeRawPointer {
        // 在, 实际使用函数的时候, 该确定的类型一定都是确定好了. 所以在方法里面, 直接使用类型参数是没有问题的.
        // 在泛型编程里面, 把类型参数, 当做变量使用.
        let delegateIdentifier = ObjectIdentifier(Delegate.self)
        // 没有一个从 ObjectIdentifier 到 Pointer 的转换函数, 这里的 Int 只是转型的需要.
        let integerIdentifier = Int(bitPattern: delegateIdentifier)
        return UnsafeRawPointer(bitPattern: integerIdentifier)!
    }
}

// workaround of Delegate: class
extension DelegateProxyType {
    
    static func _currentDelegate(for object: ParentObject) -> AnyObject? {
        currentDelegate(for: object).map { $0 as AnyObject }
    }
    
    // 在这里, 将 object 的代理赋值给了 delegate
    static func _setCurrentDelegate(_ delegate: AnyObject?, to object: ParentObject) {
        setCurrentDelegate(castOptionalOrFatalError(delegate), to: object)
    }
    
    func _forwardToDelegate() -> AnyObject? {
        self.forwardToDelegate().map { $0 as AnyObject }
    }
    
    func _setForwardToDelegate(_ forwardToDelegate: AnyObject?, retainDelegate: Bool) {
        self.setForwardToDelegate(
            castOptionalOrFatalError(forwardToDelegate),
            retainDelegate: retainDelegate)
    }
}

extension DelegateProxyType {
    
    /// Store DelegateProxy subclass to factory.
    /// When make 'Rx*DelegateProxy' subclass, call 'Rx*DelegateProxySubclass.register(for:_)' 1 time, or use it in DelegateProxyFactory
    /// 'Rx*DelegateProxy' can have one subclass implementation per concrete ParentObject type.
    /// Should call it from concrete DelegateProxy type, not generic.
    
    public static func register<Parent>(make: @escaping (Parent) -> Self) {
        self.factory.extend(make: make)
    }
    
    /// Creates new proxy for target object.
    /// Should not call this function directory, use 'DelegateProxy.proxy(for:)'
    
    // 创建 Proxy 的过程.
    public static func createProxy(for object: AnyObject) -> Self {
        castOrFatalError(factory.createProxy(for: object))
    }
    
    /// Returns existing proxy for object or installs new instance of delegate proxy.
    ///
    /// - parameter object: Target object on which to install delegate proxy.
    /// - returns: Installed instance of delegate proxy.
    ///
    ///
    ///     extension Reactive where Base: UISearchBar {
    ///
    ///         public var delegate: DelegateProxy<UISearchBar, UISearchBarDelegate> {
    ///            return RxSearchBarDelegateProxy.proxy(for: base)
    ///         }
    ///
    ///         public var text: ControlProperty<String> {
    ///             let source: Observable<String> = self.delegate.observe(#selector(UISearchBarDelegate.searchBar(_:textDidChange:)))
    ///             ...
    ///         }
    ///     }
    
    // 这是一个工厂方法, 里面会 object 和 生成 Proxy 对象的 Proxy 绑定机制.
    // 每次都要经过这个方法, 原因在于, 外界可能会修改 delegate 对象. 这里频繁的调用, 可以让这个值, 重新变为 proxy 家族的值, 然后把原来的值, 当做 forward delegate
    // 这个方法, 带有副作用. 
    public static func proxy(for object: ParentObject) -> Self {
        MainScheduler.ensureRunningOnMainThread()
        
        // 这里会避免, 重复进行生成 ParentObject 的 RxDelegate 对象的.
        let maybeProxy = self.assignedProxy(for: object)
        
        let proxy: AnyObject
        if let existingProxy = maybeProxy {
            proxy = existingProxy
        } else {
            // 如果, ParentObject 上, 还没有 rxDelegate 对象, 就用工厂方法生成一个.
            proxy = castOrFatalError(self.createProxy(for: object))
            // 在这里, 会将 生成的 proxy 对象, 寄生在 object 上, 这也就是, 为什么叫做 ParentObject 的原因.
            self.assignProxy(proxy, toObject: object)
            assert(self.assignedProxy(for: object) === proxy)
        }
        let currentDelegate = self._currentDelegate(for: object)
        let delegateProxy: Self = castOrFatalError(proxy)
        
        /*
         这里指的是, 原本 ParentObject 已经有一个 Delegate. 现在要用 RxDelegate 来进行接管.
         因为, 在 Cocoa 的设计里面, delegate 只能有一个, 所以这里多了一层, forwardToDelegate 的设计.
         */
        if currentDelegate !== delegateProxy {
            delegateProxy._setForwardToDelegate(currentDelegate, retainDelegate: false)
            // 然后, 用 RxDelegate 替换真正的 Delegate.
            self._setCurrentDelegate(proxy, to: object)
        }
        
        return delegateProxy
    }
    
    /// Sets forward delegate for `DelegateProxyType` associated with a specific object and return disposable that can be used to unset the forward to delegate.
    /// Using this method will also make sure that potential original object cached selectors are cleared and will report any accidental forward delegate mutations.
    ///
    /// - parameter forwardDelegate: Delegate object to set.
    /// - parameter retainDelegate: Retain `forwardDelegate` while it's being set.
    /// - parameter onProxyForObject: Object that has `delegate` property.
    /// - returns: Disposable object that can be used to clear forward delegate.
    public static func installForwardDelegate(_ forwardDelegate: Delegate, retainDelegate: Bool, onProxyForObject object: ParentObject) -> Disposable {
        weak var weakForwardDelegate: AnyObject? = forwardDelegate as AnyObject
        let proxy = self.proxy(for: object)
        
        assert(proxy._forwardToDelegate() === nil, "This is a feature to warn you that there is already a delegate (or data source) set somewhere previously. The action you are trying to perform will clear that delegate (data source) and that means that some of your features that depend on that delegate (data source) being set will likely stop working.\n" +
               "If you are ok with this, try to set delegate (data source) to `nil` in front of this operation.\n" +
               " This is the source object value: \(object)\n" +
               " This is the original delegate (data source) value: \(proxy.forwardToDelegate()!)\n" +
               "Hint: Maybe delegate was already set in xib or storyboard and now it's being overwritten in code.\n")
        
        proxy.setForwardToDelegate(forwardDelegate, retainDelegate: retainDelegate)
        
        return Disposables.create {
            MainScheduler.ensureRunningOnMainThread()
            
            let delegate: AnyObject? = weakForwardDelegate
            
            assert(delegate == nil || proxy._forwardToDelegate() === delegate, "Delegate was changed from time it was first set. Current \(String(describing: proxy.forwardToDelegate())), and it should have been \(proxy)")
            
            proxy.setForwardToDelegate(nil, retainDelegate: retainDelegate)
        }
    }
}


// private extensions
extension DelegateProxyType {
    
    private static var factory: DelegateProxyFactory {
        DelegateProxyFactory.sharedFactory(for: self)
    }
    
    private static func assignedProxy(for object: ParentObject) -> AnyObject? {
        let maybeDelegate = objc_getAssociatedObject(object, self.identifier)
        return castOptionalOrFatalError(maybeDelegate)
    }
    
    private static func assignProxy(_ proxy: AnyObject, toObject object: ParentObject) {
        // 强引用.
        objc_setAssociatedObject(object, self.identifier, proxy, .OBJC_ASSOCIATION_RETAIN)
    }
}

// 一个专门的抽象类型, 只要能够提供一个 Delegate 对象即可.
public protocol HasDelegate: AnyObject {
    /// Delegate type
    associatedtype Delegate
    
    /// Delegate
    var delegate: Delegate? { get set }
}

extension DelegateProxyType where ParentObject: HasDelegate,
                                  Self.Delegate == ParentObject.Delegate {
    public static func currentDelegate(for object: ParentObject) -> Delegate? {
        object.delegate
    }
    
    // 实际的设置代理的地方.
    public static func setCurrentDelegate(_ delegate: Delegate?, to object: ParentObject) {
        object.delegate = delegate
    }
}

/// Describes an object that has a data source.
public protocol HasDataSource: AnyObject {
    /// Data source type
    associatedtype DataSource
    
    /// Data source
    var dataSource: DataSource? { get set }
}

extension DelegateProxyType where ParentObject: HasDataSource,
                                  Self.Delegate == ParentObject.DataSource {
    public static func currentDelegate(for object: ParentObject) -> Delegate? {
        object.dataSource
    }
    
    public static func setCurrentDelegate(_ delegate: Delegate?, to object: ParentObject) {
        object.dataSource = delegate
    }
}

/// Describes an object that has a prefetch data source.
@available(iOS 10.0, tvOS 10.0, *)
public protocol HasPrefetchDataSource: AnyObject {
    /// Prefetch data source type
    associatedtype PrefetchDataSource
    
    /// Prefetch data source
    var prefetchDataSource: PrefetchDataSource? { get set }
}

@available(iOS 10.0, tvOS 10.0, *)
extension DelegateProxyType where ParentObject: HasPrefetchDataSource, Self.Delegate == ParentObject.PrefetchDataSource {
    public static func currentDelegate(for object: ParentObject) -> Delegate? {
        object.prefetchDataSource
    }
    
    public static func setCurrentDelegate(_ delegate: Delegate?, to object: ParentObject) {
        object.prefetchDataSource = delegate
    }
}

#if os(iOS) || os(tvOS)
import UIKit

extension ObservableType {
    func subscribeProxyDataSource<DelegateProxy: DelegateProxyType>(ofObject object: DelegateProxy.ParentObject, dataSource: DelegateProxy.Delegate, retainDataSource: Bool, binding: @escaping (DelegateProxy, Event<Element>) -> Void)
    -> Disposable
    where DelegateProxy.ParentObject: UIView
    , DelegateProxy.Delegate: AnyObject {
        let proxy = DelegateProxy.proxy(for: object)
        let unregisterDelegate = DelegateProxy.installForwardDelegate(dataSource, retainDelegate: retainDataSource, onProxyForObject: object)
        
        // Do not perform layoutIfNeeded if the object is still not in the view hierarchy
        if object.window != nil {
            // this is needed to flush any delayed old state (https://github.com/RxSwiftCommunity/RxDataSources/pull/75)
            object.layoutIfNeeded()
        }
        
        let subscription = self.asObservable()
            .observe(on:MainScheduler())
            .catch { error in
                bindingError(error)
                return Observable.empty()
            }
        // source can never end, otherwise it would release the subscriber, and deallocate the data source
            .concat(Observable.never())
            .take(until: object.rx.deallocated)
            .subscribe { [weak object] (event: Event<Element>) in
                
                binding(proxy, event)
                
                switch event {
                case .error(let error):
                    bindingError(error)
                    unregisterDelegate.dispose()
                case .completed:
                    unregisterDelegate.dispose()
                default:
                    break
                }
            }
        
        return Disposables.create { [weak object] in
            subscription.dispose()
            
            if object?.window != nil {
                object?.layoutIfNeeded()
            }
            
            unregisterDelegate.dispose()
        }
    }
}

#endif

/*
 
 To add delegate proxy subclasses call `DelegateProxySubclass.register()` in `registerKnownImplementations` or
 in some other part of your app that executes before using `rx.*` (e.g. appDidFinishLaunching).
 
 class RxScrollViewDelegateProxy: DelegateProxy {
 public static func registerKnownImplementations() {
 self.register { RxTableViewDelegateProxy(parentObject: $0) }
 }
 ...
 
 
 */

/*
 设计了一个工厂类, 那么就需要一个机制, 来为这个工厂类, 注册它的工厂方法.
 工厂类, 就是产出一个对象, 接受所需要的参数, 产出对应的对象出来.
 */
private class DelegateProxyFactory {
    
    /*
     将, 数据封装到内部. 提供静态方法进行注册和调用.
     */
    private static var _sharedFactories: [UnsafeRawPointer: DelegateProxyFactory] = [:]
    
    // 工厂类的缓存机制.
    // 传入一个类对象进来, 返回生成这个类的实例对象的工厂对象.
    fileprivate static func sharedFactory<DelegateProxy: DelegateProxyType>(
        for proxyType: DelegateProxy.Type) -> DelegateProxyFactory {
        
        // 导出都有缓存的机制. 所以, 要限制必须在一个线程在做这个事情.
        MainScheduler.ensureRunningOnMainThread()
        
        // 懒加载的机制 .
        let identifier = DelegateProxy.identifier
        if let factory = _sharedFactories[identifier] {
            return factory
        }
        
        let factory = DelegateProxyFactory(for: proxyType)
        _sharedFactories[identifier] = factory
        
        /*
         真正的把类型参数当做参数用的使用典范.
         只有第一次使用的时候, 才会去调用 registerKnownImplementations
         */
        DelegateProxy.registerKnownImplementations()
        return factory
    }
    
    // 存储, Type 的 指针值, 对应工厂生成方法.
    // 工厂方法, 是一个闭包, 传入需要 Delegate 的对象, 返回 Delegate 对象.
    private var _factories: [ObjectIdentifier: ((AnyObject) -> AnyObject)]
    private var _delegateProxyType: Any.Type
    private var _identifier: UnsafeRawPointer
    
    // 私有构造方法, 因为只会通过 static 方法才会调用. 外界不能使用.
    private init<DelegateProxy: DelegateProxyType>(for proxyType: DelegateProxy.Type) {
        self._factories = [:]
        self._delegateProxyType = proxyType
        self._identifier = proxyType.identifier
    }
    
    // 在函数式编程里面, 函数就是按照自己的业务命名的, 不会有 action, Block 这种结尾.
    fileprivate func extend<DelegateProxy: DelegateProxyType, ParentObject>(make: @escaping (ParentObject) -> DelegateProxy) {
        MainScheduler.ensureRunningOnMainThread()
        
        guard self._factories[ObjectIdentifier(ParentObject.self)] == nil else {
            rxFatalError("The factory of \(ParentObject.self) is duplicated. DelegateProxy is not allowed of duplicated base object type.")
        }
        // 这里是, 实际的进行工厂方法注册的地方 .
        // 每一个 DelegateProxy 都要实现 registerKnownImplementations 方法, 将如何生成 Proxy 的过程 ,注册到 factory 的内部.
        self._factories[ObjectIdentifier(ParentObject.self)] = { make(castOrFatalError($0)) }
    }
    
    fileprivate func createProxy(for object: AnyObject) -> AnyObject {
        
        var maybeMirror: Mirror? = Mirror(reflecting: object)
        while let mirror = maybeMirror {
            if let factory = self._factories[ObjectIdentifier(mirror.subjectType)] {
                return factory(object)
            }
            // 找不到就用父类的.
            maybeMirror = mirror.superclassMirror
        }
        rxFatalError("DelegateProxy has no factory of \(object). Implement DelegateProxy subclass for \(object) first.")
    }
}

#endif
