//
//  LogStatement.swift
//  Loggy
//
//  Created by Zachary Waldowski on 8/9/17.
//  Copyright © 2017-2018 Big Nerd Ranch. Licensed under MIT.
//

import Foundation
import CoreGraphics

/// A string literal that can be formatted into a log stream.
///
/// A log statement acts as a recipe for writing to the console log on Apple
/// platforms. If the system determines the log statement need not be emitted,
/// it will not be calculated. This improves performance, maybe significantly,
/// while your application is not attached to a debugger. If you remain
/// diligent about your log categories (`debug`, `info`, `error`, etc.), this
/// behavior protects against leaking sensitive data.
///
/// You generally don't need to create instances of this type on your own. It
/// will be created on your behalf when using a string literal with `OSLog`, or
/// when implementing `CustomLogConvertible`.
public struct LogStatement {

    enum Variant {
        case literal(String)
        case bool(Bool)
        case int8(Int8)
        case uint8(UInt8)
        case int16(Int16)
        case uint16(UInt16)
        case int32(Int32)
        case uint32(UInt32)
        case int64(Int64)
        case uint64(UInt64)
        case int(Int)
        case uint(UInt)
        case float(Float)
        case double(Double)
        case string(String)
        case object(Unmanaged<AnyObject>)
        case multiple([Variant])
    }

    let variant: Variant

    /// Creates an empty log statement.
    public init() {
        variant = .literal("")
    }

}

extension LogStatement: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        variant = .literal(value)
    }

}

extension LogStatement: _ExpressibleByStringInterpolation {

    public init(stringInterpolation statements: LogStatement...) {
        if let variant = statements.first?.variant, statements.dropFirst().isEmpty {
            self.variant = variant
        } else {
            var segments = [Variant]()
            for (i, substring) in statements.enumerated() {
                switch substring.variant {
                case .string(let value) where i % 2 == 0:
                    segments.append(.literal(value))
                case .multiple(let others):
                    segments.append(contentsOf: others)
                case let other:
                    segments.append(other)
                }
            }
            self.variant = .multiple(segments)
        }
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: Bool) {
        variant = .bool(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: Int8) {
        variant = .int8(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: UInt8) {
        variant = .uint8(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: Int16) {
        variant = .int16(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: UInt16) {
        variant = .uint16(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: Int32) {
        variant = .int32(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: UInt32) {
        variant = .uint32(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: Int64) {
        variant = .int64(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: UInt64) {
        variant = .uint64(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: Int) {
        variant = .int(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: UInt) {
        variant = .uint(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: Float) {
        variant = .float(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: Double) {
        variant = .double(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: String) {
        variant = .string(expression)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    public init(stringInterpolationSegment expression: NSObject) {
        // Trap door for printing like Obj-C would.
        //
        // Unretained because we're not creating a new object. The description
        // will be fetched within the containing log method. If we retained,
        // `"\(self)" as LogStatement` in a `deinit` would explode.
        variant = .object(Unmanaged.passUnretained(expression))
    }

    // Fallback for when the compiler finds no better version.
    public init<T>(stringInterpolationSegment expression: T) {
        variant = .string(String(describing: expression))
    }

}

extension LogStatement {

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    @_inlineable
    public init(stringInterpolationSegment expression: LogStatement) {
        self = expression
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    @_inlineable
    public init<Subject: BinaryInteger>(stringInterpolationSegment expression: Subject) {
        self.init(stringInterpolationSegment: numericCast(expression) as Int64)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    @_inlineable
    public init<Subject: UnsignedInteger>(stringInterpolationSegment expression: Subject) {
        self.init(stringInterpolationSegment: numericCast(expression) as UInt64)
    }

    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    @_inlineable
    public init(stringInterpolationSegment expression: CGFloat) {
        self.init(stringInterpolationSegment: expression.native)
    }

    #if swift(>=4.1.99)
    /// Creates a log statement for printing the contents of the given
    /// `expression`.
    ///
    /// Do not call this initializer directly. It is used by the compiler when
    /// interpreting string interpolations.
    @_inlineable
    public init<Subject: BinaryFloatingPoint>(stringInterpolationSegment expression: Subject) {
        self.init(stringInterpolationSegment: Double(expression))
    }
    #endif

}

private extension LogStatement.Variant {

    func write(formatTo format: inout String, argumentsTo arguments: inout [CVarArg]) {
        switch self {
        case .literal(let value):
            format.append(value.replacingOccurrences(of: "%", with: "%%"))
        case .bool(false):
            format.append("%@")
            arguments.append("false")
        case .bool(true):
            format.append("%@")
            arguments.append("true")
        case .int8(let value):
            format.append("%hhd")
            arguments.append(value)
        case .uint8(let value):
            format.append("%hhu")
            arguments.append(value)
        case .int16(let value):
            format.append("%hd")
            arguments.append(value)
        case .uint16(let value):
            format.append("%hu")
            arguments.append(value)
        case .int32(let value):
            format.append("%d")
            arguments.append(value)
        case .uint32(let value):
            format.append("%u")
            arguments.append(value)
        case .int64(let value):
            format.append("%lld")
            arguments.append(value)
        case .uint64(let value):
            format.append("%llu")
            arguments.append(value)
        case .int(let value):
            format.append("%zd")
            arguments.append(value)
        case .uint(let value):
            format.append("%zu")
            arguments.append(value)
        case .float(let value):
            format.append("%.*g")
            arguments.append(FLT_DIG)
            arguments.append(value)
        case .double(let value):
            format.append("%.*g")
            arguments.append(DBL_DIG)
            arguments.append(value)
        case .string(let string):
            format.append("%@")
            arguments.append(string)
        case .object(let object):
            format.append("%@")
            arguments.append(OpaquePointer(object.toOpaque()))
        case .multiple(let others):
            for other in others {
                other.write(formatTo: &format, argumentsTo: &arguments)
            }
        }
    }

}

extension LogStatement: CustomStringConvertible {

    public var description: String {
        var format = ""
        var arguments = [CVarArg]()
        variant.write(formatTo: &format, argumentsTo: &arguments)
        return String(format: format, arguments: arguments)
    }

}
