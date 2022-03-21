//
//  SchedulerType+SharedSequence.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 8/27/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxSwift

public enum SharingScheduler {
    /// Default scheduler used in SharedSequence based traits.
    /// 使用主线程的调度器.
    public private(set) static var make: () -> SchedulerType = { MainScheduler() }
    
    /**
     This method can be used in unit tests to ensure that built in shared sequences are using mock schedulers instead
     of main schedulers.
     
     **This shouldn't be used in normal release builds.**
     */
    static public func mock(scheduler: SchedulerType, action: () throws -> Void) rethrows {
        return try mock(makeScheduler: { scheduler }, action: action)
    }
    
    /**
     This method can be used in unit tests to ensure that built in shared sequences are using mock schedulers instead
     of main schedulers.
     
     **This shouldn't be used in normal release builds.**
     */
    static public func mock(makeScheduler: @escaping () -> SchedulerType, action: () throws -> Void) rethrows {
        let originalMake = make
        make = makeScheduler
        defer {
            make = originalMake
        }
        
        try action()
        
    }
}

#if os(Linux)
import Glibc
#else
import Foundation
#endif
