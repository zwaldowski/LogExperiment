//
//  CustomLogConvertible.swift
//  Loggy
//
//  Created by Zachary Waldowski on 9/8/16.
//  Copyright © 2016-2018 Big Nerd Ranch. Licensed under MIT.
//

import Foundation

/// A type with a customized log representation.
///
/// Types that conform to the `CustomLogConvertible` protocol can provide
/// their own representation to be used when writing to `OSLog`.
///
/// Accessing a type's `logStatement` property directly is discouraged.
///
/// Conforming to the CustomLogConvertible Protocol
/// ===============================================
///
/// Add `CustomLogConvertible` conformance to your custom types by defining
/// a `logStatement` property.
///
/// For example, this custom `Point` struct uses the default representation
/// supplied by the standard library:
///
///     struct Point {
///         let x: Int, y: Int
///     }
///
///     let p = Point(x: 21, y: 30)
///     OSLog.debug("I'm making a point: \(p)")
///     // Logs "I'm making a point: <redacted>" to Console
///
/// After implementing `CustomLogConvertible` conformance, the `Point`
/// type provides a custom representation:
///
///     extension Point: CustomLogConvertible {
///         var logStatement: LogStatement {
///             return "(\(x), \(y))"
///         }
///     }
///
///     OSLog.debug("I'm making a point: \(p)")
///     // Logs "I'm making a point: (21, 30)" to Console
///
/// - see: `CustomStringConvertible`
public protocol CustomLogConvertible {

    /// A programmer's representation of `self`. The returned value is printed
    /// to the console log.
    var logStatement: LogStatement { get }

}

extension LogStatement {

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    @_inlineable
    public init<Subject: CustomLogConvertible>(stringInterpolationSegment expression: Subject) {
        self = expression.logStatement
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    @_inlineable
    public init<Subject: BinaryInteger & CustomLogConvertible>(stringInterpolationSegment expression: Subject) {
        // This method is needed as a generics tiebreaker.
        self = expression.logStatement
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    @_inlineable
    public init<Subject: UnsignedInteger & CustomLogConvertible>(stringInterpolationSegment expression: Subject) {
        // This method is needed as a generics tiebreaker.
        self = expression.logStatement
    }

    #if swift(>=4.1.99)
    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    @_inlineable
    public init<Subject: BinaryFloatingPoint & CustomLogConvertible>(stringInterpolationSegment expression: Subject) {
        // This method is needed as a generics tiebreaker.
        self = expression.logStatement
    }
    #endif

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: NSObject & CustomLogConvertible) {
        // This method is needed as a generics tiebreaker.
        self = expression.logStatement
    }

}
