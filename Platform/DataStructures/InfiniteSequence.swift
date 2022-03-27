/*
 Repeat 一定次数的 Sequence.
 
 这个会在 Retry 中使用.
 */
struct InfiniteSequence<Element> : Sequence {
    
    typealias Iterator = AnyIterator<Element>
    
    private let repeatedValue: Element
    
    init(repeatedValue: Element) {
        self.repeatedValue = repeatedValue
    }
    
    func makeIterator() -> Iterator {
        let repeatedValue = self.repeatedValue
        // AnyIterator, 存储一个 Block. 在 next 的时候, 使用 Block 来获取值.
        // Block 内, 应该有对应的更新 Index 和 返回相应位置值的操作.
        return AnyIterator { repeatedValue }
    }
}
