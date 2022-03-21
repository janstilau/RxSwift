//
//  String+URL.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 12/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//


extension String {
    var URLEscaped: String {
        /*
         Returns a new string created by replacing all characters in the string not in the specified set with percent encoded characters.
         */
        return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    }
}
