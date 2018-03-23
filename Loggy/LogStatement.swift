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
        case signed(Int)
        case unsigned(UInt)
        case float(Double, precision: CInt)
        case object(Unmanaged<AnyObject>)
    }

    let segments: [Segment]

    fileprivate init(_ segments: [Segment]) {
        self.segments = segments
    }

    fileprivate init(_ segment: String) {
        self.segments = [ .literal(segment) ]
    }

    fileprivate init(_ int: Int) {
        self.segments = [ .signed(int) ]
    }

    fileprivate init(_ int: UInt) {
        self.segments = [ .unsigned(int) ]
    }

    fileprivate init(_ double: Double, precision: CInt) {
        self.segments = [ .float(double, precision: precision) ]
    }

    fileprivate init(object: UnsafeRawPointer) {
        self.segments = [ .object(object) ]
    }

}

extension LogStatement: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self.init(value)
    }

}

extension LogStatement: _ExpressibleByStringInterpolation {

    public init(stringInterpolation strings: LogStatement...) {
        self.init(strings.flatMap({ $0.segments }))
    }

    public init(stringInterpolationSegment segment: String) {
        self.init(segment)
    }

    public init(stringInterpolationSegment statement: LogStatement) {
        self = statement
    }

    public init(stringInterpolationSegment expression: Float) {
        self.init(Double(expression), precision: FLT_DIG)
    }

    public init(stringInterpolationSegment expression: Double) {
        self.init(expression, precision: DBL_DIG)
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

    public init<T: Integer>(stringInterpolationSegment expression: T) {
        self.init(Int(expression))
    }

    public init<T: UnsignedInteger>(stringInterpolationSegment expression: T) {
        self.init(UInt(expression))
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
