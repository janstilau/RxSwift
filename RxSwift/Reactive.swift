/*
 Use `Reactive` proxy as customization point for constrained protocol extensions.
 
 General pattern would be:
 
 // 1. Extend Reactive protocol with constrain on Base
 // Read as: Reactive Extension where Base is a SomeType
 extension Reactive where Base: SomeType {
 // 2. Put any specific reactive extension for SomeType here
 }
 
 With this approach we can have more specialized methods and properties using
 `Base` and not just specialized on common base type.
 
 `Binder`s are also automatically synthesized using `@dynamicMemberLookup` for writable reference properties of the reactive base.
 */

// 这是一个非常非常常用的写法.
/*
 struct Reactive<Base>  是一个 warpper. 并且是 @dynamicMemberLookup 标记的.
 如果, 使用的 property 是 Reactive 没有定义的属性, 就会走 subscript<Property>(dynamicMember 的逻辑.
 其中, 就有判断是否是所包装对象属性的 keyPath 的判断逻辑在.
 如果是, 就生成一个 Binder. Binder 里面的闭包逻辑就是, 使用 keyPath, 将新的信号发送的过来的值, 赋值到 target 对应的属性上.
 */
@dynamicMemberLookup
public struct Reactive<Base> {
    
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
    
    public subscript<Property>(dynamicMember keyPath: ReferenceWritableKeyPath<Base, Property>) -> Binder<Property>
    where Base: AnyObject {
        // Binder 封装的是一个 On 方法.
        // 而这个 On 方法, 就是使用前方信号的数据, 进行 base[keyPath: keyPath] = value 的赋值操作.
        // 这就是 bind(to: label.rx.text) 能成功的原因. Binder 是一个 Observer
        Binder(self.base) { base, value in
            base[keyPath: keyPath] = value
        }
    }
}

/// A type that has reactive extensions.
public protocol ReactiveCompatible {
    /// Extended type
    associatedtype ReactiveBase
    
    /// Reactive extensions.
    static var rx: Reactive<ReactiveBase>.Type { get set }
    
    /// Reactive extensions.
    var rx: Reactive<ReactiveBase> { get set }
}

extension ReactiveCompatible {
    /// Reactive extensions.
    public static var rx: Reactive<Self>.Type {
        get { Reactive<Self>.self }
        // this enables using Reactive to "mutate" base type
        // swiftlint:disable:next unused_setter_value
        set { }
    }
    
    /// Reactive extensions.
    public var rx: Reactive<Self> {
        get { Reactive(self) }
        // this enables using Reactive to "mutate" base object
        // swiftlint:disable:next unused_setter_value
        set { }
    }
}

import Foundation

extension NSObject: ReactiveCompatible { }
