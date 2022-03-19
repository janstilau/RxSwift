import CoreLocation
import RxSwift
import RxCocoa

// 通过 typealiase, 确定了 HasDelegate 中 Delegate 的类型. 
extension CLLocationManager: HasDelegate {
    public typealias Delegate = CLLocationManagerDelegate
}

public class RxCLLocationManagerDelegateProxy
: DelegateProxy<CLLocationManager, CLLocationManagerDelegate>
, DelegateProxyType ,
CLLocationManagerDelegate {
    
    public static func registerKnownImplementations() {
        self.register { RxCLLocationManagerDelegateProxy(locationManager: $0) }
    }
    
    public init(locationManager: CLLocationManager) {
        super.init(parentObject: locationManager,
                   delegateProxy: RxCLLocationManagerDelegateProxy.self)
    }
    
    // 使用 Subject, 来做原有的指令式世界, 到响应式世界的跳转机制.
    internal lazy var didUpdateLocationsSubject = PublishSubject<[CLLocation]>()
    internal lazy var didFailWithErrorSubject = PublishSubject<Error>()
    
    
    // 在这里, 要真正的实现, CLLocationManager 的 Delegate 方法.
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        _forwardToDelegate?.locationManager?(manager, didUpdateLocations: locations)
        didUpdateLocationsSubject.onNext(locations)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        _forwardToDelegate?.locationManager?(manager, didFailWithError: error)
        didFailWithErrorSubject.onNext(error)
    }
    
    deinit {
        // Deinit, 做结束的基础.
        self.didUpdateLocationsSubject.on(.completed)
        self.didFailWithErrorSubject.on(.completed)
    }
}
