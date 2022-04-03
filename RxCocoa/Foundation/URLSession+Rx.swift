//
//  URLSession+Rx.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 3/23/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation
import RxSwift

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// 对于 Swfit 来说, 定义一个 Swift.Error 的 Error, 和定义一个 Code 其实没有太大的区别.
public enum RxCocoaURLError : Swift.Error {
    /// Unknown error occurred.
    case unknown // 一个默认的错误分类方式. 然后其他的, 就是 rxURL 的细化了.
    /// Response is not NSHTTPURLResponse
    case nonHTTPResponse(response: URLResponse)
    /// Response is not successful. (not in `200 ..< 300` range)
    case httpRequestFailed(response: HTTPURLResponse, data: Data?)
    /// Deserialization error.
    case deserializationError(error: Swift.Error)
}

// 对于 debugDescription 的维护, 类, 单独 extension 来完成对于协议的适配.
extension RxCocoaURLError: CustomDebugStringConvertible {
    /// A textual representation of `self`, suitable for debugging.
    public var debugDescription: String {
        switch self {
        case .unknown:
            return "Unknown error has occurred."
        case let .nonHTTPResponse(response):
            return "Response is not NSHTTPURLResponse `\(response)`."
        case let .httpRequestFailed(response, _):
            return "HTTP request failed with `\(response.statusCode)`."
        case let .deserializationError(error):
            return "Error during deserialization of the response: \(error)"
        }
    }
}

private func escapeTerminalString(_ value: String) -> String {
    return value.replacingOccurrences(of: "\"", with: "\\\"", options:[], range: nil)
}

/*
 Curl 作为一个命令, 有着自己的格式.
 本身, Http 请求就是一个文本请求, 所以一个 Http 请求, 一定是可以变为一个 curl 请求的.
 */
private func convertURLRequestToCurlCommand(_ request: URLRequest) -> String {
    let method = request.httpMethod ?? "GET"
    var returnValue = "curl -X \(method) "
    
    if let httpBody = request.httpBody {
        let maybeBody = String(data: httpBody, encoding: String.Encoding.utf8)
        if let body = maybeBody {
            // 对于 curl 来说, 专门的一个 -d, 来标明后续的是请求体.
            returnValue += "-d \"\(escapeTerminalString(body))\" "
        }
    }
    
    for (key, value) in request.allHTTPHeaderFields ?? [:] {
        let escapedKey = escapeTerminalString(key as String)
        let escapedValue = escapeTerminalString(value as String)
        // 参数, 是用 -H 来表示, 另外起一行
        returnValue += "\n    -H \"\(escapedKey): \(escapedValue)\" "
    }
    
    let URLString = request.url?.absoluteString ?? "<unknown url>"
    
    // URL 在最后
    returnValue += "\n\"\(escapeTerminalString(URLString))\""
    
    // 固定的命令尾
    returnValue += " -i -v"
    
    return returnValue
}

// 这是一个 Debug 方法.
private func convertResponseToString(_ response: URLResponse?, _ error: NSError?, _ interval: TimeInterval) -> String {
    // 真实因为, 在 iOS 里面的时间戳是和常用的不一致.
    let ms = Int(interval * 1000)
    
    if let response = response as? HTTPURLResponse {
        if 200 ..< 300 ~= response.statusCode {
            return "Success (\(ms)ms): Status \(response.statusCode)"
        } else {
            return "Failure (\(ms)ms): Status \(response.statusCode)"
        }
    }
    
    if let error = error {
        // 如何判断, 是否是取消, 使用特殊的 Domain 和 Code 进行判断就可以了.
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            return "Canceled (\(ms)ms)"
        }
        return "Failure (\(ms)ms): NSError > \(error)"
    }
    
    return "<Unhandled response from server>"
}

extension Reactive where Base: URLSession {
    /**
     Observable sequence of responses for URL request.
     Performing of request starts after observer is subscribed and not after invoking this method.
     **URL requests will be performed per subscribed observer.**
     Any error during fetching of the response will cause observed sequence to terminate with error.
     */
    // 上面讲的很清楚, 是每一个 subscribe 都会引起一次新的网络请求.
    // 这是最最通用的网络请求的响应了, 就是 Resposne + Data.
    // 使用 URLSession 的 DataTask 这个方法创建一个 Observable
    // 可以看到, 使用 Observable.create 是将指令式的代码, 转化成为响应式的代码, 最常用的方式.
    public func response(request: URLRequest) -> Observable<(response: HTTPURLResponse, data: Data)> {
        return Observable.create { observer in
            // 使用 URLSession 的 DataTask 来进行真正的网络请求, 然后在回调里面, 进行 observer 的状态的确定.
            let task = self.base.dataTask(with: request) { data, response, error in
                
                guard let response = response, let data = data else {
                    // 如果, 没有成功, 那么就是 error 的发送.
                    observer.on(.error(error ?? RxCocoaURLError.unknown))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    // 如果不是 Http 请求, 也是会报错的.
                    observer.on(.error(RxCocoaURLError.nonHTTPResponse(response: response)))
                    return
                }
                
                // 将响应值, data 值通过 next 发送出去, 并且立马发送一个 Complete. 这是正确的, 应为对于网络请求来说, 就是数据来领后, 表示错误
                observer.on(.next((httpResponse, data)))
                observer.on(.completed)
            }
            
            task.resume()
            
            // 返回的 Subscribe, 就是 Task 进行 cancel.
            // 当, taskCancel 后, 还是会触发 dataTask 里面的回调.
            // 所以, 这个 Observable 还是可以正常的进行终点.
            return Disposables.create(with: task.cancel)
        }
    }
    
    /**
     Observable sequence of response data for URL request.
     
     Performing of request starts after observer is subscribed and not after invoking this method.
     
     **URL requests will be performed per subscribed observer.**
     
     Any error during fetching of the response will cause observed sequence to terminate with error.
     
     If response is not HTTP response with status code in the range of `200 ..< 300`, sequence
     will terminate with `(RxCocoaErrorDomain, RxCocoaError.NetworkError)`.
     
     - parameter request: URL request.
     - returns: Observable sequence of response data.
     */
    public func data(request: URLRequest) -> Observable<Data> {
        return self.response(request: request).map { pair -> Data in
            if 200 ..< 300 ~= pair.0.statusCode {
                return pair.1
            }
            else {
                throw RxCocoaURLError.httpRequestFailed(response: pair.0, data: pair.1)
            }
        }
    }
    
    /**
     Observable sequence of response JSON for URL request.
     
     Performing of request starts after observer is subscribed and not after invoking this method.
     
     **URL requests will be performed per subscribed observer.**
     
     Any error during fetching of the response will cause observed sequence to terminate with error.
     
     If response is not HTTP response with status code in the range of `200 ..< 300`, sequence
     will terminate with `(RxCocoaErrorDomain, RxCocoaError.NetworkError)`.
     
     If there is an error during JSON deserialization observable sequence will fail with that error.
     
     - parameter request: URL request.
     - returns: Observable sequence of response JSON.
     */
    public func json(request: URLRequest, options: JSONSerialization.ReadingOptions = []) -> Observable<Any> {
        return self.data(request: request).map { data -> Any in
            do {
                return try JSONSerialization.jsonObject(with: data, options: options)
            } catch let error {
                throw RxCocoaURLError.deserializationError(error: error)
            }
        }
    }
    
    /**
     Observable sequence of response JSON for GET request with `URL`.
     
     Performing of request starts after observer is subscribed and not after invoking this method.
     
     **URL requests will be performed per subscribed observer.**
     
     Any error during fetching of the response will cause observed sequence to terminate with error.
     
     If response is not HTTP response with status code in the range of `200 ..< 300`, sequence
     will terminate with `(RxCocoaErrorDomain, RxCocoaError.NetworkError)`.
     
     If there is an error during JSON deserialization observable sequence will fail with that error.
     
     - parameter url: URL of `NSURLRequest` request.
     - returns: Observable sequence of response JSON.
     */
    public func json(url: Foundation.URL) -> Observable<Any> {
        self.json(request: URLRequest(url: url))
    }
}

extension Reactive where Base == URLSession {
    /// Log URL requests to standard output in curl format.
    public static var shouldLogRequest: (URLRequest) -> Bool = { _ in
        // 编译选项, 进行方法分开编译.
#if DEBUG
        return true
#else
        return false
#endif
    }
}
