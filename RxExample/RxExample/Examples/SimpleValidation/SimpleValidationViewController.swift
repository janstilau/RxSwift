//
//  SimpleValidationViewController.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 12/6/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

private let minimalUsernameLength = 5
private let minimalPasswordLength = 5

enum State {
    case play
    case stop(Int, String)
}

class SimpleValidationViewController : ViewController {
    
    @IBOutlet weak var usernameOutlet: UITextField!
    @IBOutlet weak var usernameValidOutlet: UILabel!
    
    @IBOutlet weak var passwordOutlet: UITextField!
    @IBOutlet weak var passwordValidOutlet: UILabel!
    
    @IBOutlet weak var doSomethingOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        usernameValidOutlet.text = "Username has to be at least \(minimalUsernameLength) characters"
        passwordValidOutlet.text = "Password has to be at least \(minimalPasswordLength) characters"
        
        /*
         usernameOutlet.rx.text 是作为 Publisher 在这个链式调用中存在的.
         */
        let usernameValid = usernameOutlet.rx.text.orEmpty
            .map { $0.count >= minimalUsernameLength }
            .share(replay: 1) // without this map would be executed once for each binding, rx is stateless by default
        
        let passwordValid = passwordOutlet.rx.text.orEmpty
            .map { $0.count >= minimalPasswordLength }
            .share(replay: 1)
        
        // Observable.combineLatest, 必须要有值
        // 这里使用 share, 使得后面的 bind, 使用同一个 Observable.
        let everythingValid = Observable.combineLatest(usernameValid, passwordValid) { $0 && $1 }
            .share(replay: 1)
        
        /*
         同, 指令式回调注册, 显示在回调中, 指定 check 函数, 更新 UI 相比, 响应式将 UI 处理, 按照 UI 相关的逻辑进行了分离.
         在指令式的代码里面, 操作回调中专门进行 UI 操作, 很快就会让代码逻辑复杂. 但是如果所有的操作回调都触发总的 Update, 又会有性能问题.
         这种响应式的代码, 好处就在于, UI 的改变会在一个地方. 逻辑集中. 并且减少了注册的过程. 这些过程都隐藏在了框架的实现里面, 将回调这件事, 使用信号发送的模式进行了统一.
         每种 UI 的改变, 仅仅和触发的信号相关, 性能上, 应该会有提升.
         */
        usernameValid
            .bind(to: passwordOutlet.rx.isEnabled)
            .disposed(by: disposeBag)
        
        usernameValid
            .bind(to: usernameValidOutlet.rx.isHidden)
            .disposed(by: disposeBag)
        
        passwordValid
            .bind(to: passwordValidOutlet.rx.isHidden)
            .disposed(by: disposeBag)
        
        everythingValid
            .bind(to: doSomethingOutlet.rx.isEnabled)
            .disposed(by: disposeBag)
        
        // 在不能直接进行 bind 之后, 还是可以使用 subscribe, 使用命令式的操作, 将逻辑继续进行下去.
        doSomethingOutlet.rx.tap
            .subscribe(onNext: { [weak self] _ in self?.showAlert() })
            .disposed(by: disposeBag)
    }
    
    func showAlert() {
        let alert = UIAlertController(
            title: "RxExample",
            message: "This is wonderful",
            preferredStyle: .alert
        )
        let defaultAction = UIAlertAction(title: "Ok",
                                          style: .default,
                                          handler: nil)
        alert.addAction(defaultAction)
        present(alert, animated: true, completion: nil)
    }
}
