//
//  Bag.swift
//  Platform
//
//  Created by Krunoslav Zaher on 2/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Swift

let arrayDictionaryMaxSize = 30

struct BagKey {
    // 直接使用的 Int64 作为 Key. 理论上, 不会出问题.
    fileprivate let rawValue: UInt64
}

/*
 Bag 是一个复合的数据结构.
 先是一个特殊的位置.
 然后是数组存储.
 最后是字典存储.
 */
/*
 Bag 里面, Element 的数据类型不定, 根据传入的参数来确定.
 */
struct Bag<T> : CustomDebugStringConvertible {
    /// Type of identifier for inserted elements.
    typealias KeyType = BagKey
    
    typealias Entry = (key: BagKey, value: T)
    
    private var _nextKey: BagKey = BagKey(rawValue: 0)
    
    // 不太明白, 为什么使用 _ 开头进行命名.
    // data
    // 单值的存储, 使用了一个 key 进行绑定.
    var _key0: BagKey?
    var _value0: T?
    
    // 数组存储, 利用数组, 进行遍历查询.
    var _pairs = ContiguousArray<Entry>()
    
    // Map 值存储, 最后的存储.
    var _dictionary: [BagKey: T]?
    
    var _onlyFastPath = true
    
    /// Creates new empty `Bag`.
    init() { }
    
    /**
     Inserts `value` into bag.
     
     - parameter element: Element to insert.
     - returns: Key that can be used to remove element from bag.
     */
    mutating func insert(_ element: T) -> BagKey {
        let key = _nextKey
        
        _nextKey = BagKey(rawValue: _nextKey.rawValue &+ 1)
        
        // 如果, 还没有占用那个特殊的位置, 占用了
        if _key0 == nil {
            _key0 = key
            _value0 = element
            return key
        }
        
        // 一次性属性, 只要量多过, 就没有单值存储了.
        // 这个值, 仅仅在 Get 的时候使用过.
        _onlyFastPath = false
        
        // 如果, 已经使用了 Dict, 那么就直接 Dict 插入.
        if _dictionary != nil {
            _dictionary![key] = element
            return key
        }
        
        // 如果, 数组还没有填满, 添加
        if _pairs.count < arrayDictionaryMaxSize {
            // 数组里面, 存储的是 key value 的 pair.
            _pairs.append((key: key, value: element))
            return key
        }
        
        _dictionary = [key: element]
        
        return key
    }
    
    // Count 累加.
    var count: Int {
        let dictionaryCount: Int = _dictionary?.count ?? 0
        return (_value0 != nil ? 1 : 0) + _pairs.count + dictionaryCount
    }
    
    /// Removes all elements from bag and clears capacity.
    mutating func removeAll() {
        _key0 = nil
        _value0 = nil
        
        _pairs.removeAll(keepingCapacity: false)
        _dictionary?.removeAll(keepingCapacity: false)
    }
    
    /**
     Removes element with a specific `key` from bag.
     
     - parameter key: Key that identifies element to remove from bag.
     - returns: Element that bag contained, or nil in case element was already removed.
     */
    mutating func removeKey(_ key: BagKey) -> T? {
        if _key0 == key {
            _key0 = nil
            let value = _value0!
            _value0 = nil
            return value
        }
        
        if let existingObject = _dictionary?.removeValue(forKey: key) {
            return existingObject
        }
        
        for i in 0 ..< _pairs.count where _pairs[i].key == key {
            let value = _pairs[i].value
            _pairs.remove(at: i)
            return value
        }
        
        return nil
    }
}

extension Bag {
    var debugDescription : String {
        "\(self.count) elements in Bag"
    }
}

extension Bag {
    /// Enumerates elements inside the bag.
    ///
    /// - parameter action: Enumeration closure.
    func forEach(_ action: (T) -> Void) {
        if _onlyFastPath {
            if let value0 = _value0 {
                action(value0)
            }
            return
        }
        
        let value0 = _value0
        let dictionary = _dictionary
        
        if let value0 = value0 {
            action(value0)
        }
        
        for i in 0 ..< _pairs.count {
            action(_pairs[i].value)
        }
        
        if dictionary?.count ?? 0 > 0 {
            for element in dictionary!.values {
                action(element)
            }
        }
    }
}

extension BagKey: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

func ==(lhs: BagKey, rhs: BagKey) -> Bool {
    lhs.rawValue == rhs.rawValue
}
