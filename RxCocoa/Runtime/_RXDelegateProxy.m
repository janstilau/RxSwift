//
//  _RXDelegateProxy.m
//  RxCocoa
//
//  Created by Krunoslav Zaher on 7/4/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#import "include/_RXDelegateProxy.h"
#import "include/_RX.h"
#import "include/_RXObjCRuntime.h"

@interface _RXDelegateProxy () {
    // 记录一下, 原来的 Delegate 对象.
    id __weak __forwardToDelegate;
}

@property (nonatomic, strong) id strongForwardDelegate;

@end

static NSMutableDictionary *voidSelectorsPerClass = nil;

@implementation _RXDelegateProxy

+(NSSet*)collectVoidSelectorsForProtocol:(Protocol *)protocol {
    NSMutableSet *selectors = [NSMutableSet set];

    unsigned int protocolMethodCount = 0;
    struct objc_method_description *pMethods =
    protocol_copyMethodDescriptionList(protocol, NO, YES, &protocolMethodCount);

    for (unsigned int i = 0; i < protocolMethodCount; ++i) {
        struct objc_method_description method = pMethods[i];
        if (RX_is_method_with_description_void(method)) {
            [selectors addObject:SEL_VALUE(method.name)];
        }
    }
            
    free(pMethods);
// 到这里, protocol 的所有 void 方法就已经搞定了.
    
    unsigned int numberOfBaseProtocols = 0;
    // 这里是查询 Protocol 的父类 Protocol, 然后把父类的所有方法都搞出来, 添加到 selectors 里面去..
    Protocol * __unsafe_unretained * pSubprotocols = protocol_copyProtocolList(protocol, &numberOfBaseProtocols);

    for (unsigned int i = 0; i < numberOfBaseProtocols; ++i) {
        [selectors unionSet:[self collectVoidSelectorsForProtocol:pSubprotocols[i]]];
    }
    
    free(pSubprotocols);

    return selectors;
}

/*
 这是, 每个 _RXDelegateProxy 的子类都会触发的方法.
 */
+(void)initialize {
    // 使用类对象来上锁.
    @synchronized (_RXDelegateProxy.class) {
        if (voidSelectorsPerClass == nil) {
            voidSelectorsPerClass = [[NSMutableDictionary alloc] init];
        }

        NSMutableSet *voidSelectors = [NSMutableSet set];

#define CLASS_HIERARCHY_MAX_DEPTH 100

        NSInteger  classHierarchyDepth = 0;
        Class      targetClass         = NULL;

        for (classHierarchyDepth = 0, targetClass = self;
             classHierarchyDepth < CLASS_HIERARCHY_MAX_DEPTH && targetClass != nil;
             ++classHierarchyDepth, targetClass = class_getSuperclass(targetClass)
        ) {
            unsigned int count;
            Protocol *__unsafe_unretained *pProtocols = class_copyProtocolList(targetClass, &count);
            
            for (unsigned int i = 0; i < count; i++) {
                NSSet *selectorsForProtocol = [self collectVoidSelectorsForProtocol:pProtocols[i]];
                [voidSelectors unionSet:selectorsForProtocol];
            }
            
            free(pProtocols);
        }

        if (classHierarchyDepth == CLASS_HIERARCHY_MAX_DEPTH) {
            NSLog(@"Detected weird class hierarchy with depth over %d. Starting with this class -> %@", CLASS_HIERARCHY_MAX_DEPTH, self);
#if DEBUG
            abort();
#endif
        }
        
        // 将, 一个类里面所有的 void 返回值的方法, 都从 initlization 时进行了收集.
        voidSelectorsPerClass[CLASS_VALUE(self)] = voidSelectors;
    }
}

-(id)_forwardToDelegate {
    return __forwardToDelegate;
}

-(void)_setForwardToDelegate:(id __nullable)forwardToDelegate retainDelegate:(BOOL)retainDelegate {
    // 专门一个量, 来记录原来的 delegate.
    __forwardToDelegate = forwardToDelegate;
    if (retainDelegate) {
        self.strongForwardDelegate = forwardToDelegate;
    } else {
        self.strongForwardDelegate = nil;
    }
}

-(BOOL)hasWiredImplementationForSelector:(SEL)selector {
    return [super respondsToSelector:selector];
}

-(BOOL)voidDelegateMethodsContain:(SEL)selector {
    @synchronized(_RXDelegateProxy.class) {
        NSSet *voidSelectors = voidSelectorsPerClass[CLASS_VALUE(self.class)];
        return [voidSelectors containsObject:SEL_VALUE(selector)];
    }
}

/*
 在 rx 里面, 实际上是用到了 OC 的最后一层转发机制.
 */
-(void)forwardInvocation:(NSInvocation *)anInvocation {
    BOOL isVoid = RX_is_method_signature_void(anInvocation.methodSignature);
    NSArray *arguments = nil;
    if (isVoid) {
        arguments = RX_extract_arguments(anInvocation);
        [self _sentMessage:anInvocation.selector withArguments:arguments];
    }
    
    // 这里是把调用, 传给了最初设置的, 非 RXDelegate 的版本.
    if (self._forwardToDelegate &&
        [self._forwardToDelegate respondsToSelector:anInvocation.selector]) {
        [anInvocation invokeWithTarget:self._forwardToDelegate];
    }

    if (isVoid) {
        [self _methodInvoked:anInvocation.selector withArguments:arguments];
    }
}

// 
// abstract method
-(void)_sentMessage:(SEL)selector withArguments:(NSArray *)arguments {

}

// abstract method
-(void)_methodInvoked:(SEL)selector withArguments:(NSArray *)arguments {

}

-(void)dealloc {
}

@end
