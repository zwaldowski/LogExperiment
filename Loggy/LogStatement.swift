//
//  LogStatement.swift
//  Loggy
//
//  Created by Zachary Waldowski on 8/9/17.
//  Copyright © 2017 Big Nerd Ranch. All rights reserved.
//

import Foundation
import CoreGraphics

// TODO: enable custom formatting looking like:
//
//    enum LogVisibility { case `public`, `private` }
//    format<T>(_ expression: T, for visibility: LogVisibility)
//
//    enum LogIntegerFormat { case time, errno, ipv6 }
//    Integer.format(for visibility: LogVisibility? = nil, as format: LogIntegerFormat? = nil, precision: Int? = nil)
//
//    enum LogFloatingPointFormat { case compact(uppercase: Bool) }
//    FloatingPoint.format(for visibility: LogVisibility? = nil, as format: LogFloatingPointFormat? = nil, precision: Int? = nil)
//
//    enum LogDataFormat { case timeval, timespec, uuid, socket, ipv6 }
//    Data.format(for visibility: LogVisibility? = nil, as format: LogFloatingPointFormat? = nil, precision: Int? = nil)
//    UUID.format(for visibility: LogVisibility? = nil)
//    etc.

/// A string literal that can be formatted into a log stream.
///
/// You generally don't need to create this on your own.
public struct LogStatement {

    enum Segment {
        case literal(String)
        case string(String)
        case signed(Int)
        case unsigned(UInt)
        case float(Double, precision: CInt)
        case object(Unmanaged<AnyObject>)
    }

    let segments: [Segment]

}

extension LogStatement: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        segments = [ .string(value) ]
    }

}

extension LogStatement: _ExpressibleByStringInterpolation {

    public init(stringInterpolation strings: LogStatement...) {
        segments = strings.enumerated().flatMap { (i: Int, substring: LogStatement) -> [LogStatement.Segment] in
            if i % 2 == 0, substring.segments.count == 1, case .string(let literal) = substring.segments[0] {
                return [ .literal(literal) ]
            } else {
                return substring.segments
            }
        }
    }

    // Concrete specializations.

    public init(stringInterpolationSegment statement: LogStatement) {
        self = statement
    }

    public init(stringInterpolationSegment segment: String) {
        self.init(stringLiteral: segment)
    }

    public init<T: BinaryInteger>(stringInterpolationSegment expression: T) {
        segments = [ .signed(Int(expression)) ]
    }

    public init<T: UnsignedInteger>(stringInterpolationSegment expression: T) {
        segments = [ .unsigned(UInt(expression)) ]
    }

    public init(stringInterpolationSegment expression: Float) {
        segments = [ .float(Double(expression), precision: FLT_DIG) ]
    }

    public init(stringInterpolationSegment expression: Double) {
        segments = [ .float(expression, precision: DBL_DIG) ]
    }

    public init(stringInterpolationSegment expression: CGFloat) {
        self.init(stringInterpolationSegment: expression.native)
    }

    public init<T: NSObject>(stringInterpolationSegment expression: T) {
        // Unretained because we're not creating a new object. The description
        // will be fetched within the containing log method. If we retained,
        // `"\(self)" as LogStatement` in a `deinit` would explode.
        segments = [ .object(Unmanaged.passUnretained(expression)) ]
    }

    public init<T: CustomLogConvertible>(stringInterpolationSegment expression: T) {
        self = expression.logStatement
    }

    // Needed as a tiebreaker.
    public init<T: BinaryInteger & CustomLogConvertible>(stringInterpolationSegment expression: T) {
        self = expression.logStatement
    }

    // Needed as a tiebreaker.
    public init<T: UnsignedInteger & CustomLogConvertible>(stringInterpolationSegment expression: T) {
        self = expression.logStatement
    }

    // Needed as a tiebreaker.
    public init<T: NSObject & CustomLogConvertible>(stringInterpolationSegment expression: T) {
        self = expression.logStatement
    }

    // Fallback for when the compiler finds no better version.
    public init<T>(stringInterpolationSegment expression: T) {
        // Retained because we are creating a derived object.
        let string = String(describing: expression) as NSString
        segments = [ .object(Unmanaged.passRetained(string).autorelease()) ]
    }

}

extension LogStatement: CustomStringConvertible {

    public var description: String {
        var format = ""
        var arguments = [CVarArg]()

        for segment in segments {
            switch segment {
            case .literal(let string):
                format.append(string)
            case .string(let string):
                format.append("%@")
                arguments.append(string)
            case .signed(let int):
                format.append("%zd")
                arguments.append(int)
            case .unsigned(let int):
                format.append("%zu")
                arguments.append(int)
            case .float(let double, let precision):
                format.append("%.*g")
                arguments.append(precision)
                arguments.append(double)
            case .object(let object):
                format.append("%@")
                arguments.append(OpaquePointer(object.toOpaque()))
            }
        }

        return String(format: format, arguments: arguments)
    }

}
