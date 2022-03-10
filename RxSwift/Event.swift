//
//  Event.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//


// @Frozen. Event 是一个核心的概念, 所以必须要固定.
@frozen public enum Event<Element> {
    /// Next element is produced.
    case next(Element)
    
    /// Sequence terminated with an error.
    case error(Swift.Error)
    
    /// Sequence completed successfully.
    case completed
}

// 单独的 Extension 单独的 Protocol 的实现, 这是从 Swfit 源码里面, 保持下来的风格.
extension Event: CustomDebugStringConvertible {
    /// Description of event.
    public var debugDescription: String {
        switch self {
        case .next(let value):
            return "next(\(value))"
        case .error(let error):
            return "error(\(error))"
        case .completed:
            return "completed"
        }
    }
}

// 这种, Enum 添加 is 查询的写法, 是很好的写法. Enum 就是一个盒子, 将盒子的拆解过程, 封装到盒子的类里面, 是正确的.
// 各种操作, 返回 Bool 也好, 返回 Optional 也好, 都能够很好的表现自己的含义.
extension Event {
    /// Is `completed` or `error` event.
    public var isStopEvent: Bool {
        switch self {
        case .next: return false
        case .error, .completed: return true
        }
    }
    
    /*
     If case
     guard case
     如果不需要进行 associate value 的获取, 直接进行 case  的比较, 是没有问题的.
     */
    
    /// If `next` event, returns element value.
    public var element: Element? {
        if case .next(let value) = self {
            return value
        }
        return nil
    }
    
    /// If `error` event, returns error.
    public var error: Swift.Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
    
    /// If `completed` event, returns `true`.
    public var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
}

extension Event {
    /// Maps sequence elements using transform. If error happens during the transform, `.error`
    /// will be returned as value.
    // 这个操作, 是和 Optinal 学的, 不过, 自己很少用这个. Enum 类型, Map 可以算作是一个固定的书写思路, 就是按照 case 进行判断, 调用.
    public func map<Result>(_ transform: (Element) throws -> Result) -> Event<Result> {
        do {
            switch self {
            case let .next(element):
                return .next(try transform(element))
            case let .error(error):
                return .error(error)
            case .completed:
                return .completed
            }
        }
        catch let e {
            return .error(e)
        }
    }
}

// 这种, Convertible 是一个非常通用的设计思路, adapter 设计的时候, 可以使用抽象接口为 Convertible, 然后 model 实现他.
// 其实还是传递的是 model, 但是给了外界一个可以扩展自己的能力. 
public protocol EventConvertible {
    /// Type of element in event
    associatedtype Element
    
    /// Event representation of this instance
    var event: Event<Element> { get }
}

extension Event: EventConvertible {
    /// Event representation of this instance
    public var event: Event<Element> { self }
}
