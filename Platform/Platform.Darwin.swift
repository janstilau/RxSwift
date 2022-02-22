//
//  Platform.Darwin.swift
//  Platform
//
//  Created by Krunoslav Zaher on 12/29/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

    import Darwin
    import Foundation

/*
 You can use the returned dictionary to store thread-specific data. The thread dictionary is not used during any manipulations of the NSThread object—it is simply a place where you can store any interesting data. For example, Foundation uses it to store the thread’s default NSConnection and NSAssertionHandler instances. You may define your own keys for the dictionary.
 */
    extension Thread {
        static func setThreadLocalStorageValue<T: AnyObject>(_ value: T?, forKey key: NSCopying) {
            let currentThread = Thread.current
            let threadDictionary = currentThread.threadDictionary

            if let newValue = value {
                threadDictionary[key] = newValue
            } else {
                threadDictionary[key] = nil
            }
        }

        static func getThreadLocalStorageValueForKey<T>(_ key: NSCopying) -> T? {
            let currentThread = Thread.current
            let threadDictionary = currentThread.threadDictionary
            
            return threadDictionary[key] as? T
        }
    }

#endif
