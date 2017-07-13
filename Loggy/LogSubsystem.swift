//
//  LogSubsystem.swift
//
//  Created by Zachary Waldowski on 9/8/16.
//  Copyright © 2016-2017 Big Nerd Ranch. Licensed under MIT.
//

import os.log
import Foundation

// MARK: - Improved logging primitives

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
public protocol CustomLogStringConvertible {
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

/// The logging namespace. All methods record to the Apple Unified Logging
/// System.
///
/// Use it when the additional context of a subsystem wouldn't be useful, or
/// when replacing legacy logging mechanisms.
///
///     Log.show("Hello, world!")
///     Log.debug("Logged in with id %@", id)
///     Log.assert(!frame.isEmpty, "You messed it up!)
///
/// - important: Log message lines greater than the system’s maximum message
///   length are truncated. Complete messages are visible when using the `log`
///   tool to view a live stream of activity.
///
/// For more info:
/// - https://developer.apple.com/documentation/os/logging?language=objc
/// - https://developer.apple.com/library/content/samplecode/Logging/Introduction/Intro.html
/// - https://developer.apple.com/videos/play/wwdc2016/721
public enum Log {

    fileprivate static func show(_ message: StaticString, type: OSLogType, isEnabled enabled: Bool = true, subsystem: String? = nil, category: String? = nil, into mirror: LogMirror? = nil, containingBinary dso: UnsafeRawPointer, arguments: [Any]) {
        // The system does bookkeeping of OSLog instances automatically.
        let log: OSLog
        if !enabled {
            log = .disabled
        } else if let subsystem = subsystem, let category = category {
            log = OSLog(subsystem: subsystem, category: category)
        } else {
            log = .default
        }

        // If neither log wants the message, do no further work.
        let nativeEnabled = log.isEnabled(type: type)

        let mirror = mirror ?? Log.mirror
        let mirrorEnabled = mirror?.isEnabled(type: type) ?? false

        guard nativeEnabled || mirrorEnabled else { return }

        // Convert into va_list form, potentially using CustomLogStringConvertible.
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

        // Send to os_log.
        if nativeEnabled {
            let returnAddress = _swift_os_log_return_address()

            message.withUTF8Buffer { (format: UnsafeBufferPointer<UInt8>) in
                withVaList(cArguments) { (valist) in
                    _swift_os_log(dso, returnAddress, log, type, format.baseAddress, valist)
                }
            }
        }

        // Send to mirror.
        if mirrorEnabled {
            mirror?.show(message, type: type, subsystem: subsystem, category: category, containingBinary: dso, cArguments)
        }
    }

    /// Issues a log message at the default level.
    ///
    /// Default-level messages are initially stored in memory and moved to the
    /// data store. Use this method to capture information about things that
    /// might result in a failure.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public static func show(_ message: StaticString, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        show(message, type: .default, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the debug level.
    ///
    /// Debug-level messages are only captured in memory when debug logging is
    /// enabled at runtime. They are intended for use in a development
    /// environment and not in shipping software.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public static func debug(_ message: StaticString, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        show(message, type: .debug, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the info level.
    ///
    /// Info-level messages are initially stored in memory, but are not moved to
    /// the data store until faults or, optionally, errors occur. Use this
    /// method to capture information that may be helpful, but isn’t essential.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public static func info(_ message: StaticString, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        show(message, type: .info, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the error level.
    ///
    /// Error-level messages are always saved in the data store.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public static func error(_ message: StaticString, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        show(message, type: .error, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the fault level.
    ///
    /// Fault-level messages are always saved in the data store.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public static func fault(_ message: StaticString, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        show(message, type: .default, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the debug level with the current function name.
    ///
    /// Debug-level messages are only captured in memory when debug logging is
    /// enabled at runtime. They are intended for use in a development
    /// environment and not in shipping software.
    ///
    /// - parameter function: The name of the function call being traced.
    ///   The default is the function where the trace was invoked.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    public static func trace(function: StaticString = #function, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        show(function, type: .debug, containingBinary: dso, arguments: [])
    }

    /// Issues a log message at the info level indicating that a sanity check
    /// failed.
    ///
    /// Use this method during development to check for invalid usage. In
    /// playgrounds or -Onone builds (the default for Xcode's Debug
    /// configuration), program execution will be stopped in a debuggable state.
    /// To fail similarly in Release builds, see `preconditionFailure`.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter file: The file name to print with `message` in a playground
    ///   or `-Onone` build.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public static func assertionFailure(_ message: StaticString, file: StaticString, line: UInt, containingBinary dso: UnsafeRawPointer, arguments: [Any]) {
        let mirror = AssertionFailureMirror(file: file, line: line)
        show(message, type: .info, into: mirror, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the info level indicating that a sanity check
    /// failed.
    ///
    /// Use this method during development to check for invalid usage. In
    /// playgrounds or -Onone builds (the default for Xcode's Debug
    /// configuration), program execution will be stopped in a debuggable state.
    /// To fail similarly in Release builds, see `preconditionFailure`.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter file: The file name to print with `message` in a playground
    ///   or `-Onone` build. The default is the file where the assertion failure
    ///   was called.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build. The default is the line where the
    ///   assertion failure was called.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   assertion failure was called.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public static func assertionFailure(_ message: StaticString, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        assertionFailure(message, file: file, line: line, containingBinary: dso, arguments: arguments)
    }

    /// Performs a sanity check. If it fails, a log message is issued at the
    /// info level.
    ///
    /// Use this method during development to check for invalid usage. The
    /// condition is always checked, but in playgrounds and -Onone builds (the
    /// default for Xcode's Debug configuration), failing the check will stop
    /// program execution in a debuggable state. To fail similarly in Release
    /// builds, see `precondition`.
    ///
    /// - parameter condition: The condition to test. It is always evaluated.
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter file: The file name to print with `message` in a playground
    ///   or `-Onone` build. The default is the file where the assertion failed.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build. The default is the line where the
    ///   assertion failed.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   assertion failed.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    @_transparent
    public static func assert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> StaticString = "", file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        guard !condition() else { return }
        assertionFailure(message(), file: file, line: line, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the error level indicating that a precondition
    /// was violated.
    ///
    /// Use this method to stop the program when control flow can only reach the
    /// call if your API was improperly used. Program execution will be stopped.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter file: The file name to print with `message`.
    /// - parameter line: The line number to print along with `message`.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public static func preconditionFailure(_ message: StaticString, file: StaticString, line: UInt, containingBinary dso: UnsafeRawPointer, arguments: [Any]) -> Never {
        let mirror = PreconditionFailureMirror(file: file, line: line)
        show(message, type: .error, into: mirror, containingBinary: dso, arguments: arguments)
        preconditionFailure("can't get here")
    }

    /// Issues a log message at the error level indicating that a precondition
    /// was violated.
    ///
    /// Use this method to stop the program when control flow can only reach the
    /// call if your API was improperly used. Program execution will be stopped.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter file: The file name to print with `message`. The default is
    ///   the file where the precondition failure occurred.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build. The default is the line where the
    ///   precondition failure occurred.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   precondition failure occurred.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public static func preconditionFailure(_ message: StaticString, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) -> Never {
        preconditionFailure(message, file: file, line: line, containingBinary: dso, arguments: arguments)
    }

    /// Checks a necessary condition for making forward progress. If it fails,
    /// a log message is issued at the error level.
    ///
    /// Use this method to stop the program when control flow can only reach the
    /// call if your API was improperly used. Error-level messages are always
    /// saved in the data store. Program execution will be stopped.
    ///
    /// - parameter condition: The condition to test. It is always evaluated.
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter file: The file name to print with `message`. The default is
    ///   the file where the precondition failed.
    /// - parameter line: The line number to print along with `message`. The
    ///   default is the line where the precondition failed.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   precondition failed.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    @_transparent
    public static func precondition(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> StaticString = "", file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        guard !condition() else { return }
        preconditionFailure(message(), file: file, line: line, containingBinary: dso, arguments: arguments)
    }

}

// MARK: - Log categorization

/// A type representing a concrete part of an application, such that it can be
/// identified in logs. All methods record to the Apple Unified Logging
/// System. Subsystem and category information can be using [LLDB or the Console application](https://developer.apple.com/documentation/os/logging#1682417).
///
/// A typical use is as a nested type:
///
///     extension MyViewController {
///         enum Log: LogSubsystem {
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
    /// The name of a subsystem, such as "networking".
    static var name: String { get }

    /// A stage or grouping for a subsystem, such as "setup" or "teardown".
    var categoryName: String { get }

    /// Whether to print any messages in this subsystem and category.
    var isEnabled: Bool { get }
}

extension LogSubsystem {

    /// By default, the description of `Self`.
    public static var name: String {
        let name = String(reflecting: self)
        let startWithModule = name.range(of: ".")?.upperBound ?? name.startIndex
        let endWithoutExtraneousName = name.range(of: ".", options: .backwards, range: startWithModule ..< name.endIndex)?.lowerBound ?? name.endIndex
        return name[name.startIndex ..< endWithoutExtraneousName]
    }

    /// By default, the description of `self`.
    public var categoryName: String {
        return String(describing: self)
    }

    /// By default, all subsystems are enabled at the code level, but some
    /// levels may be disabled at runtime.
    public var isEnabled: Bool {
        return true
    }

    /// Issues a log message at the default level.
    ///
    /// Default-level messages are initially stored in memory and moved to the
    /// data store. Use this method to capture information about things that
    /// might result in a failure.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public func show(_ message: StaticString, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        guard isEnabled else { return }
        Log.show(message, type: .default, subsystem: Self.name, category: categoryName, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the debug level.
    ///
    /// Debug-level messages are only captured in memory when debug logging is
    /// enabled at runtime. They are intended for use in a development
    /// environment and not in shipping software.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public func debug(_ message: StaticString, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        guard isEnabled else { return }
        Log.show(message, type: .debug, subsystem: Self.name, category: categoryName, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the info level.
    ///
    /// Info-level messages are initially stored in memory, but are not moved to
    /// the data store until faults or, optionally, errors occur. Use this
    /// method to capture information that may be helpful, but isn’t essential.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public func info(_ message: StaticString, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        guard isEnabled else { return }
        Log.show(message, type: .info, subsystem: Self.name, category: categoryName, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the error level.
    ///
    /// Error-level messages are always saved in the data store.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public func error(_ message: StaticString, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        guard isEnabled else { return }
        Log.show(message, type: .error, subsystem: Self.name, category: categoryName, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the fault level.
    ///
    /// Fault-level messages are always saved in the data store.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public func fault(_ message: StaticString, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        guard isEnabled else { return }
        Log.show(message, type: .fault, subsystem: Self.name, category: categoryName, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the debug level with the current function name.
    ///
    /// Debug-level messages are only captured in memory when debug logging is
    /// enabled at runtime. They are intended for use in a development
    /// environment and not in shipping software.
    ///
    /// - parameter function: The name of the function call being traced.
    ///   The default is the function where the trace was invoked.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    public func trace(function: StaticString = #function, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        guard isEnabled else { return }
        Log.show(function, type: .debug, subsystem: Self.name, category: categoryName, containingBinary: dso, arguments: [])
    }

    /// Issues a log message at the info level indicating that a sanity check
    /// failed.
    ///
    /// Use this method during development to check for invalid usage. In
    /// playgrounds or -Onone builds (the default for Xcode's Debug
    /// configuration), program execution will be stopped in a debuggable state.
    /// To fail similarly in Release builds, see `preconditionFailure`.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter file: The file name to print with `message` in a playground
    ///   or `-Onone` build.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public func assertionFailure(_ message: StaticString, file: StaticString, line: UInt, containingBinary dso: UnsafeRawPointer, arguments: [Any]) {
        let mirror = AssertionFailureMirror(file: file, line: line)
        Log.show(message, type: .error, isEnabled: isEnabled, subsystem: Self.name, category: categoryName, into: mirror, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the info level indicating that a sanity check
    /// failed.
    ///
    /// Use this method during development to check for invalid usage. In
    /// playgrounds or -Onone builds (the default for Xcode's Debug
    /// configuration), program execution will be stopped in a debuggable state.
    /// To fail similarly in Release builds, see `preconditionFailure`.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter file: The file name to print with `message` in a playground
    ///   or `-Onone` build. The default is the file where the assertion failure
    ///   was called.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build. The default is the line where the
    ///   assertion failure was called.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   assertion failure was called.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public func assertionFailure(_ message: StaticString, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        assertionFailure(message, file: file, line: line, containingBinary: dso, arguments: arguments)
    }

    /// Performs a sanity check. If it fails, a log message is issued at the
    /// info level.
    ///
    /// Use this method during development to check for invalid usage. The
    /// condition is always checked, but in playgrounds and -Onone builds (the
    /// default for Xcode's Debug configuration), failing the check will stop
    /// program execution in a debuggable state. To fail similarly in Release
    /// builds, see `precondition`.
    ///
    /// - parameter condition: The condition to test. It is always evaluated.
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter file: The file name to print with `message` in a playground
    ///   or `-Onone` build. The default is the file where the assertion failed.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build. The default is the line where the
    ///   assertion failed.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   assertion failed.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    @_transparent
    public func assert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> StaticString = "", file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        guard !condition() else { return }
        assertionFailure(message(), file: file, line: line, containingBinary: dso, arguments: arguments)
    }

    /// Issues a log message at the error level indicating that a precondition
    /// was violated.
    ///
    /// Use this method to stop the program when control flow can only reach the
    /// call if your API was improperly used. Program execution will be stopped.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter file: The file name to print with `message`.
    /// - parameter line: The line number to print along with `message`.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public func preconditionFailure(_ message: StaticString, file: StaticString, line: UInt, containingBinary dso: UnsafeRawPointer, arguments: [Any]) -> Never {
        let mirror = PreconditionFailureMirror(file: file, line: line)
        Log.show(message, type: .fault, isEnabled: isEnabled, subsystem: Self.name, category: categoryName, into: mirror, containingBinary: dso, arguments: arguments)
        preconditionFailure("can't get here")
    }

    /// Issues a log message at the error level indicating that a precondition
    /// was violated.
    ///
    /// Use this method to stop the program when control flow can only reach the
    /// call if your API was improperly used. Program execution will be stopped.
    ///
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter file: The file name to print with `message`. The default is
    ///   the file where the precondition failure occurred.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build. The default is the line where the
    ///   precondition failure occurred.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   precondition failure occurred.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    public func preconditionFailure(_ message: StaticString, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) -> Never {
        preconditionFailure(message, file: file, line: line, containingBinary: dso, arguments: arguments)
    }

    /// Checks a necessary condition for making forward progress. If it fails,
    /// a log message is issued at the error level.
    ///
    /// Use this method to stop the program when control flow can only reach the
    /// call if your API was improperly used. Error-level messages are always
    /// saved in the data store. Program execution will be stopped.
    ///
    /// - parameter condition: The condition to test. It is always evaluated.
    /// - parameter message: A `printf`-style format string. Log messages are
    ///   formatted using a variation on the [Cocoa String Format Specifiers](https://developer.apple.com/documentation/os/logging?language=objc#1682416).
    /// - parameter file: The file name to print with `message`. The default is
    ///   the file where the precondition failed.
    /// - parameter line: The line number to print along with `message`. The
    ///   default is the line where the precondition failed.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   precondition failed.
    /// - parameter arguments: Zero or more items to print corresponding to
    ///   the format `message`.
    @_transparent
    public func precondition(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> StaticString = "", file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle, _ arguments: Any...) {
        guard !condition() else { return }
        preconditionFailure(message(), file: file, line: line, containingBinary: dso, arguments: arguments)
    }

}

// MARK: - Log mirroring

/// A type that may be used as a secondary target for log subsystems.
///
/// - seealso: Log.mirror
public protocol LogMirror {
    /// Return `true` if `show` should be invoked for this mirror. Return
    /// `false` to potentially save resources if the message is to be ignored.
    func isEnabled(type: OSLogType) -> Bool

    /// Record a formatted log `message`. Structural information, such as
    /// `type`, `subsystem`, and `category` are passed to enhance log output.
    /// `dso` may be passed to dyld to get more debugging info.
    func show(_ message: String, type: OSLogType, subsystem: String?, category: String?, containingBinary dso: UnsafeRawPointer)
}

private struct AssertionFailureMirror: LogMirror {
    let file: StaticString
    let line: UInt

    func isEnabled(type: OSLogType) -> Bool {
        return true
    }

    func show(_ message: String, type: OSLogType, subsystem: String?, category: String?, containingBinary dso: UnsafeRawPointer) {
        assertionFailure(message, file: file, line: line)
    }
}

private struct PreconditionFailureMirror: LogMirror {
    let file: StaticString
    let line: UInt

    func isEnabled(type: OSLogType) -> Bool {
        return true
    }

    func show(_ message: String, type: OSLogType, subsystem: String?, category: String?, containingBinary dso: UnsafeRawPointer) {
        preconditionFailure(message, file: file, line: line)
    }
}

private let osLogSpecifiers = try! NSRegularExpression(pattern: "%\\{+?\\}(.{1})")

private extension LogMirror {

    func show(_ message: StaticString, type: OSLogType, subsystem: String?, category: String?, containingBinary dso: UnsafeRawPointer, _ arguments: [CVarArg]) {
        let message = String(describing: message)
        let format = osLogSpecifiers.stringByReplacingMatches(in: message, range: NSRange(0 ..< message.utf16.count), withTemplate: "%$1")
        show(format, type: type, subsystem: subsystem, category: category, containingBinary: arguments)
    }

}

extension Log {

    private static var mirrorLock = os_unfair_lock()
    private static var _mirror: LogMirror?

    /// A separate target for outputting log statements. This mirror should not
    /// print to the standard console output.
    public static var mirror: LogMirror? {
        get {
            os_unfair_lock_lock(&mirrorLock)
            defer { os_unfair_lock_unlock(&mirrorLock) }
            return _mirror
        }
        set {
            os_unfair_lock_lock(&mirrorLock)
            defer { os_unfair_lock_unlock(&mirrorLock) }
            _mirror = newValue
        }
    }

}

extension LogMirror {

    /// Returns the URL for the executable containing the `address`.
    public func urlContaining(_ address: UnsafeRawPointer?) -> URL? {
        var info = Dl_info()
        guard dladdr(address, &info) != 0, let fname = info.dli_fname else { return nil }
        return URL(fileURLWithPath: String(cString: fname))
    }

    /// Returns the name of the executable containing the `address`.
    public func executableContaining(_ address: UnsafeRawPointer?) -> String? {
        return urlContaining(address)?.deletingPathExtension().lastPathComponent
    }

}
