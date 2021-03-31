//
//  Application+Extensions.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 8/20/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

#if os(iOS)
    import UIKit
    typealias OSApplication = UIApplication
#elseif os(macOS)
    import Cocoa
    typealias OSApplication = NSApplication
#endif

/*
 在预编译里面, 会去除不符合编译条件的代码. 所以, iOS 里面, 其实看不到 NSApplication.
 用 typealias 将两个平台的差异性, 进行抹除.
 */

extension OSApplication {
    static var isInUITest: Bool {
        ProcessInfo.processInfo.environment["isUITest"] != nil;
    }
}
