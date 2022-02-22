//
//  Platform.Linux.swift
//  Platform
//
//  Created by Krunoslav Zaher on 12/29/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(Linux)

    import Foundation

// 实际上 MAC 平台的 Thread.threadDict 也很有可能是这样实现的. 
    extension Thread {

        static func setThreadLocalStorageValue<T: AnyObject>(_ value: T?, forKey key: String) {
            if let newValue = value {
                Thread.current.threadDictionary[key] = newValue
            }
            else {
                Thread.current.threadDictionary[key] = nil
            }
        }

        static func getThreadLocalStorageValueForKey<T: AnyObject>(_ key: String) -> T? {
            let currentThread = Thread.current
            let threadDictionary = currentThread.threadDictionary

            return threadDictionary[key] as? T
        }
    }

#endif
