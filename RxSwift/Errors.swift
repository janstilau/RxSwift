//
//  Errors.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

let RxErrorDomain       = "RxErrorDomain"
let RxCompositeFailures = "RxCompositeFailures"

/*
 应该多多定义自己的 Error 类型.
 使用 Enum 来代表 Error, 和使用 Code 代表 Error 没有太大的区别.
 但是, 这是一个类型, 所以就能够添加各种相关的方法在内. 
 */
public enum RxError
    : Swift.Error
    , CustomDebugStringConvertible {
    /// Unknown error occurred.
    case unknown
    /// Performing an action on disposed object.
    case disposed(object: AnyObject)
    /// Arithmetic overflow error.
    case overflow
    /// Argument out of range error.
    case argumentOutOfRange
    /// Sequence doesn't contain any elements.
    case noElements
    /// Sequence contains more than one element.
    case moreThanOneElement
    /// Timeout error.
    case timeout
}

extension RxError {
    /// A textual representation of `self`, suitable for debugging.
    public var debugDescription: String {
        switch self {
        case .unknown:
            return "Unknown error occurred."
        case .disposed(let object):
            return "Object `\(object)` was already disposed."
        case .overflow:
            return "Arithmetic overflow occurred."
        case .argumentOutOfRange:
            return "Argument out of range."
        case .noElements:
            return "Sequence doesn't contain any elements."
        case .moreThanOneElement:
            return "Sequence contains more than one element."
        case .timeout:
            return "Sequence timeout."
        }
    }
}
