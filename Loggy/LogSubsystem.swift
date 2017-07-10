//
//  LogSubsystem.swift
//
//  Created by Zachary Waldowski on 9/8/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import os.log

/// A type representing an concrete part of an application, such that it can be
/// identified in logs.
///
/// A typical use is as a nested type:
///
///     extension MyViewController {
///         enum Log: Error {
///             case user
///             case network
///         }
///         
///         @IBAction func userTappedButton(_ sender: Any) {
///             Log.user.debug("They tapped the button!")
///         }
///         
///         func requestFailed(error: Error) {
///             Log.network.error("Could not log in: %@", error)
///         }
///     }
///
public protocol LogSubsystem {
    /// The name of a subsystem, such as "com.myapp.networking".
    ///
    /// By default, the fully-qualified name of `self`.
    static var name: String { get }
    
    /// A stage or grouping for a subsystem, such as "setup" or "teardown".
    ///
    /// By default, the description of `self`.
    var categoryName: String { get }
}

/// A type with a customized log representation.
///
/// Types that conform to the `CustomLogStringConvertible` protocol can provide
/// their own representation to be used when logging using a `LogSubsystem`.
///
/// Accessing a type's `logValue` property directly is discouraged.
///
/// Conforming to the CustomLogStringConvertible Protocol
/// =====================================================
///
/// Add `CustomLogStringConvertible` conformance to your custom types by defining
/// a `logValue` property.
///
/// For example, this custom `Point` struct uses the default representation
/// supplied by the standard library:
///
///     struct Point {
///         let x: Int, y: Int
///     }
///
///     let p = Point(x: 21, y: 30)
///     Log.show("%@", p)
///     // Logs "Point(x: 21, y: 30)"
///
/// After implementing `CustomLogStringConvertible` conformance, the `Point`
/// type provides a custom representation:
///
///     extension Point: CustomLogConvertible {
///         var logDescription: String {
///             return "(\(x), \(y))"
///         }
///     }
///
///     Log.show("%@", p)
///     // Logs "(21, 30)"
///
/// - see: `CustomStringConvertible`
protocol CustomLogStringConvertible {
    /// A programmer's representation of `self`. The returned value is printed
    /// to the console log.
    var logDescription: String { get }
}

extension String {
    
    /// Creates a console log representing the given `value`.
    public init<Subject>(logging instance: Subject) {
        if let subject = instance as? CustomLogStringConvertible {
            self = String(describing: subject.logDescription)
        } else {
            self = String(describing: instance)
        }
    }
    
}

// MARK: Default implementation

extension LogSubsystem {
    
    public static var name: String {
        return String(reflecting: self)
    }
    
    public var categoryName: String {
        return String(describing: self)
    }
    
}

private extension OSLog {
    
    func show(_ message: StaticString, dso: UnsafeRawPointer?, level: OSLogType, _ arguments: [Any]) {
        guard isEnabled(type: level) else { return }
        let returnAddress = _swift_os_log_return_address()
        let cArguments = arguments.map { (argument) -> CVarArg in
            switch argument {
            case let value as CustomLogStringConvertible:
                return value.logDescription as NSString
            case let value as CVarArg:
                return value
            default:
                return String(describing: argument) as NSString
            }
        }

        message.withUTF8Buffer { (format: UnsafeBufferPointer<UInt8>) in
            withVaList(cArguments) { (valist) in
                _swift_os_log(dso, returnAddress, self, level, format.baseAddress, valist)
            }
        }
    }

}

extension LogSubsystem {

    private var log: OSLog {
        // The system does bookkeeping of OSLog instances by subsystem and
        // category, so we don't need to deal with caching or thread-safety.
        return OSLog(subsystem: Self.name, category: categoryName)
    }

    public func show(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ arguments: Any...) {
        log.show(message, dso: dso, level: .default, arguments)
    }
    
    public func debug(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ arguments: Any...) {
        log.show(message, dso: dso, level: .debug, arguments)
    }
    
    public func info(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ arguments: Any...) {
        log.show(message, dso: dso, level: .info, arguments)
    }
    
    public func error(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ arguments: Any...) {
        log.show(message, dso: dso, level: .error, arguments)
    }
    
    public func fault(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ arguments: Any...) {
        log.show(message, dso: dso, level: .fault, arguments)
    }
    
    public func trace(function: StaticString = #function, dso: UnsafeRawPointer? = #dsohandle) {
        log.show(function, dso: dso, level: .debug, [])
    }
    
}

enum Log {

    public static func show(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        OSLog.default.show(message, dso: dso, level: .default, args)
    }

    public static func debug(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        OSLog.default.show(message, dso: dso, level: .debug, args)
    }

    public static func info(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        OSLog.default.show(message, dso: dso, level: .info, args)
    }

    public static func error(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        OSLog.default.show(message, dso: dso, level: .error, args)
    }

    public static func fault(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        OSLog.default.show(message, dso: dso, level: .default, args)
    }
    
    public static func trace(function: StaticString = #function, dso: UnsafeRawPointer? = #dsohandle) {
        OSLog.default.show(function, dso: dso, level: .debug, [])
    }
    
}
