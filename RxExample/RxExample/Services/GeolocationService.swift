//
//  GeolocationService.swift
//  RxExample
//
//  Created by Carlos García on 19/01/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import CoreLocation
import RxSwift
import RxCocoa

class GeolocationService {
    
    static let instance = GeolocationService()
    
    private (set) var authorized: Driver<Bool>
    private (set) var location: Driver<CLLocationCoordinate2D>
    
    // 真正和系统打交道, 还是要使用系统的类.
    private let locationManager = CLLocationManager()
    
    private init() {
        
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        // 这里, 没有 weak self, 而是 [weak locationManager].
        authorized = Observable.deferred { [weak locationManager] in
            // 把当前的状态值拿到手.
            // 这里创建一个监听 auth status 的事件序列, 然后第一个值, 是现在拿到的状态值. 所以, 后续节点一定会收到信号.
            // 这个信号, 是当前的 CL 的状态值. 后边收到的, 才是 CL 的变化值.
            let status = CLLocationManager.authorizationStatus()
            guard let locationManager = locationManager else {
                return Observable.just(status)
            }
            return locationManager
                .rx.didChangeAuthorizationStatus
                .startWith(status)
        }
        .asDriver(onErrorJustReturn: CLAuthorizationStatus.notDetermined)
        .map {
            switch $0 {
            case .authorizedAlways:
                return true
            case .authorizedWhenInUse:
                return true
            default:
                return false
            }
        }
        
        location = locationManager.rx.didUpdateLocations
            .asDriver(onErrorJustReturn: [])
        // 位置变化了, 取最后一个, 变化为 Driver, 然后取里面的坐标值 .
            .flatMap {
                return $0.last.map(Driver.just) ?? Driver.empty()
            }
            .map { $0.coordinate }
        
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }
    
}
