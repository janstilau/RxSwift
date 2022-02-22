//
//  Attributes.h
//  RxExample
//
//  Created by JustinLau on 2022/2/22.
//  Copyright © 2022 Krunoslav Zaher. All rights reserved.
//

#ifndef Attributes_h
#define Attributes_h

/*
 dynamicMemberLookup
 Apply this attribute to a class, structure, enumeration, or protocol to enable members to be looked up by name at runtime. The type must implement a subscript(dynamicMember:) subscript.

 In an explicit member expression, if there isn’t a corresponding declaration for the named member, the expression is understood as a call to the type’s subscript(dynamicMember:) subscript, passing information about the member as the argument. The subscript can accept a parameter that’s either a key path or a member name; if you implement both subscripts, the subscript that takes key path argument is used.

 An implementation of subscript(dynamicMember:) can accept key paths using an argument of type KeyPath, WritableKeyPath, or ReferenceWritableKeyPath. It can accept member names using an argument of a type that conforms to the ExpressibleByStringLiteral protocol—in most cases, String. The subscript’s return type can be any type.

 Dynamic member lookup by member name can be used to create a wrapper type around data that can’t be type checked at compile time, such as when bridging data from other languages into Swift. For example:

 @dynamicMemberLookup
 struct DynamicStruct {
     let dictionary = ["someDynamicMember": 325,
                       "someOtherMember": 787]
     subscript(dynamicMember member: String) -> Int {
         return dictionary[member] ?? 1054
     }
 }
 let s = DynamicStruct()

 // Use dynamic member lookup.
 let dynamic = s.someDynamicMember
 print(dynamic)
 // Prints "325"

 // Call the underlying subscript directly.
 let equivalent = s[dynamicMember: "someDynamicMember"]
 print(dynamic == equivalent)
 // Prints "true"
 Dynamic member lookup by key path can be used to implement a wrapper type in a way that supports compile-time type checking. For example:

 struct Point { var x, y: Int }

 @dynamicMemberLookup
 struct PassthroughWrapper<Value> {
     var value: Value
     subscript<T>(dynamicMember member: KeyPath<Value, T>) -> T {
         get { return value[keyPath: member] }
     }
 }

 let point = Point(x: 381, y: 431)
 let wrapper = PassthroughWrapper(value: point)
 print(wrapper.x)
 */

#endif /* Attributes_h */
