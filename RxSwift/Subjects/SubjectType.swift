//
//  SubjectType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/1/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// Represents an object that is both an observable sequence as well as an observer.
// SubjectType 就是, 既可以充当发布者, 也可以充当监听者.

public protocol SubjectType : ObservableType {
    /// The type of the observer that represents this subject.
    ///
    /// Usually this type is type of subject itself, but it doesn't have to be.
    associatedtype Observer: ObserverType

    /// Returns observer interface for subject.
    ///
    /// - returns: Observer interface for subject.
    func asObserver() -> Observer
}
