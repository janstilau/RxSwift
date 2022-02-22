//
//  NumbersViewController.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 12/6/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class DynamicClass {
    var variableMember: Int = 1
    let constantMember: Int = 2
    var variableObj: NSObject = NSObject()
    let constantObj: NSObject = NSObject()
    
    var obj: DynamicClass?
    
    init() {
        print("Inited")
    }
}

@dynamicMemberLookup
struct DynamicStruct {
    
    var memberName: String = "呵呵哒"
    let dictionary = ["someDynamicMember": 325,
                      "someOtherMember": 787]
    
    var variableMember: Int = 1
    let constantMember: Int = 2
    var variableObj: NSObject = NSObject()
    let constantObj: NSObject = NSObject()
    
    subscript(dynamicMember member: String) -> Int {
        return dictionary[member] ?? 1054
    }
    
    subscript(dynamicMember member: String) -> String {
        return "heheda"
    }
    
    subscript<T>(dynamicMember member: KeyPath<DynamicStruct, T>) -> T {
        get { return self[keyPath: member] }
    }
}

struct IUser {
    let name: String = "name"
    let email: String = "email"
    let address: Address? = nil
    let role: Role = .admin
    
    var commonValue: String = "commonValue"
}

// 2
struct Address {
    let street: String
}

// 3
enum Role {
    case admin
    case member
    case guest
    
    var permissions: [Permission] {
        switch self {
        case .admin:
            return [.create, .read, .update, .delete]
        case .member:
            return [.create, .read]
        case .guest:
            return [.read]
        }
    }
}

// 4
enum Permission {
    case create
    case read
    case update
    case delete
}

struct ThePoint {
    var x: Int = 1
    var y: Int = 2
    var commonValue: Int = 3
}

@dynamicMemberLookup
struct PassthroughWrapper<Value> {
    var value: Value
    subscript<T>(dynamicMember member: KeyPath<Value, T>) -> T {
        get { return value[keyPath: member] }
    }
}

@dynamicMemberLookup
struct Container {
    var value1: ThePoint
    var value2: IUser
    
    subscript<T>(dynamicMember member: KeyPath<ThePoint, T>) -> T {
        get { return value1[keyPath: member] }
    }
    subscript<T>(dynamicMember member: KeyPath<IUser, T>) -> T {
        get { return value2[keyPath: member] }
    }
}


class NumbersViewController: ViewController {
    @IBOutlet weak var number1: UITextField!
    @IBOutlet weak var number2: UITextField!
    @IBOutlet weak var number3: UITextField!

    @IBOutlet weak var result: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        Observable.combineLatest(number1.rx.text.orEmpty, number2.rx.text.orEmpty, number3.rx.text.orEmpty) { textValue1, textValue2, textValue3 -> Int in
                return (Int(textValue1) ?? 0) + (Int(textValue2) ?? 0) + (Int(textValue3) ?? 0)
            }
            .map { $0.description }
            .bind(to: result.rx.text)
            .disposed(by: disposeBag)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        testKeypath()
    }
    
    func testCase() {
        let s = DynamicStruct()

        // Use dynamic member lookup.
        let dynamic: Int = s.someDynamicMember
        print(dynamic)
        // Prints "325"

        // Call the underlying subscript directly.
        let equivalent: String = s.someDynamicMember
        print(equivalent)
        // Prints "true"
        
        let memberKeyPath = \DynamicStruct.memberName
        let memberValue = s[dynamicMember: memberKeyPath]
        print(memberValue)
        
        let point = ThePoint(x: 381, y: 431)
        let wrapper = PassthroughWrapper(value: point)
        print(wrapper.y)
    }
    
    func testKeypath() {
        let point = ThePoint()
        let user = IUser()
        let contianer = Container.init(value1: point, value2: user)
        let a = contianer.y
        let b = contianer.name
        let c: String = contianer.commonValue
        let d: Int = contianer.commonValue
    }
    
    func testStructType() {
        let a = \DynamicStruct.variableMember
        let b = \DynamicStruct.constantMember
        
        let c = \DynamicStruct.variableObj
        let d = \DynamicStruct.constantObj
        
        print(a)
        print(b)
        print(c)
        print(d)
        print("")
    }
    
    func testClassType() {
        let a = \DynamicClass.variableMember
        let b = \DynamicClass.constantMember
        
        let c = \DynamicClass.variableObj
        let d = \DynamicClass.constantObj
        
        let e = \DynamicClass.obj
        
        print(a)
        print(b)
        print(c)
        print(d)
        print(e)
        print("")
    }
    
    func testLinkTypes() {
        let a = \DynamicClass.obj?.variableMember
        let b = \DynamicClass.obj?.constantMember
        
        let c = \DynamicClass.obj?.variableObj
        let d = \DynamicClass.obj?.constantObj
        let e = \DynamicClass.obj?.obj
        
        print(a)
        print(b)
        print(c)
        print(d)
        print(e)
        print("")
    }
    
    func testUser() {
        // 1
        let stringDebugDescription = \String.debugDescription
        // KeyPath

        // 2
        let userRole = \IUser.role
        // KeyPath

        // 3
        let firstIndexInteger = \[Int][0]
        // WritableKeyPath<[Int], Int>

        // 4
        let firstInteger = \Array<Int>.first
        // KeyPath<[Int], Int?>
        
        print(stringDebugDescription)
        print(userRole)
        print(firstIndexInteger)
        print(firstInteger)
    }
}

class Animal: NSObject {
    @objc var name: String
    
    init(name: String) {
        self.name = name
    }
}



 
