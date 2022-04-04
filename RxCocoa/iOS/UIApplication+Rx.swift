//
//  UIApplication+Rx.swift
//  RxCocoa
//
//  Created by Mads Bøgeskov on 18/01/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

#if os(iOS)

import UIKit
import RxSwift

extension Reactive where Base: UIApplication {
    
    // Binder, 存储了当信号来临的时候, 应该怎么使用信号中的元素, 来更新存储的 UI 对象.
    // Binder 是一个 Observer, 所以, 这是信号链的终点.
    public var isNetworkActivityIndicatorVisible: Binder<Bool> {
        return Binder(self.base) { application, active in
            application.isNetworkActivityIndicatorVisible = active
        }
    }
    
    // 包装了通知检测的机制, 在触发后, 进行信号的发送.
    public static var didEnterBackground: ControlEvent<Void> {
        let source = NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification).map { _ in }
        return ControlEvent(events: source)
    }
    
    /// Reactive wrapper for `UIApplication.willEnterForegroundNotification`
    public static var willEnterForeground: ControlEvent<Void> {
        let source = NotificationCenter.default.rx.notification(UIApplication.willEnterForegroundNotification).map { _ in }
        
        return ControlEvent(events: source)
    }
    
    /// Reactive wrapper for `UIApplication.didFinishLaunchingNotification`
    public static var didFinishLaunching: ControlEvent<Void> {
        let source = NotificationCenter.default.rx.notification(UIApplication.didFinishLaunchingNotification).map { _ in }
        
        return ControlEvent(events: source)
    }
    
    /// Reactive wrapper for `UIApplication.didBecomeActiveNotification`
    public static var didBecomeActive: ControlEvent<Void> {
        let source = NotificationCenter.default.rx.notification(UIApplication.didBecomeActiveNotification).map { _ in }
        
        return ControlEvent(events: source)
    }
    
    /// Reactive wrapper for `UIApplication.willResignActiveNotification`
    public static var willResignActive: ControlEvent<Void> {
        let source = NotificationCenter.default.rx.notification(UIApplication.willResignActiveNotification).map { _ in }
        
        return ControlEvent(events: source)
    }
    
    /// Reactive wrapper for `UIApplication.didReceiveMemoryWarningNotification`
    public static var didReceiveMemoryWarning: ControlEvent<Void> {
        let source = NotificationCenter.default.rx.notification(UIApplication.didReceiveMemoryWarningNotification).map { _ in }
        
        return ControlEvent(events: source)
    }
    
    /// Reactive wrapper for `UIApplication.willTerminateNotification`
    public static var willTerminate: ControlEvent<Void> {
        let source = NotificationCenter.default.rx.notification(UIApplication.willTerminateNotification).map { _ in }
        
        return ControlEvent(events: source)
    }
    
    /// Reactive wrapper for `UIApplication.significantTimeChangeNotification`
    public static var significantTimeChange: ControlEvent<Void> {
        let source = NotificationCenter.default.rx.notification(UIApplication.significantTimeChangeNotification).map { _ in }
        
        return ControlEvent(events: source)
    }
    
    /// Reactive wrapper for `UIApplication.backgroundRefreshStatusDidChangeNotification`
    public static var backgroundRefreshStatusDidChange: ControlEvent<Void> {
        let source = NotificationCenter.default.rx.notification(UIApplication.backgroundRefreshStatusDidChangeNotification).map { _ in }
        
        return ControlEvent(events: source)
    }
    
    /// Reactive wrapper for `UIApplication.protectedDataWillBecomeUnavailableNotification`
    public static var protectedDataWillBecomeUnavailable: ControlEvent<Void> {
        let source = NotificationCenter.default.rx.notification(UIApplication.protectedDataWillBecomeUnavailableNotification).map { _ in }
        
        return ControlEvent(events: source)
    }
    
    /// Reactive wrapper for `UIApplication.protectedDataDidBecomeAvailableNotification`
    public static var protectedDataDidBecomeAvailable: ControlEvent<Void> {
        let source = NotificationCenter.default.rx.notification(UIApplication.protectedDataDidBecomeAvailableNotification).map { _ in }
        
        return ControlEvent(events: source)
    }
    
    /// Reactive wrapper for `UIApplication.userDidTakeScreenshotNotification`
    public static var userDidTakeScreenshot: ControlEvent<Void> {
        // 原来还有 userDidTakeScreenshotNotification 这个通知, 可以直接拿到截屏的通知.
        let source = NotificationCenter.default.rx.notification(UIApplication.userDidTakeScreenshotNotification).map { _ in }
        return ControlEvent(events: source)
    }
}
#endif
