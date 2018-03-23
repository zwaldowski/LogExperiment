//
//  LogSubsystem.swift
//
//  Created by Zachary Waldowski on 9/8/16.
//  Copyright © 2016-2018 Big Nerd Ranch. Licensed under MIT.
//

import os.log
import Foundation

// Lots of docs
// swiftlint:disable file_length

// MARK: - Improved logging primitives

/// A type with a customized log representation.
///
/// Types that conform to the `CustomLogConvertible` protocol can provide
/// their own representation to be used when logging using a `LogSubsystem`.
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
///     Log.show("Point of order: \(p)")
///     // Logs "Point of order: <redacted>" to Console
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
///     Log.show("Point of order: \(p)")
///     // Logs "Point of order: (21, 30)" to Console
///
/// - see: `CustomStringConvertible`
public protocol CustomLogConvertible {
    /// A programmer's representation of `self`. The returned value is printed
    /// to the console log.
    var logStatement: LogStatement { get }
}

/// The logging namespace. All methods record to the Apple Unified Logging
/// System.
///
/// Use it when the additional context of a subsystem wouldn't be useful, or
/// when replacing legacy logging mechanisms.
///
///     Log.show("Hello, world!")
///     Log.debug("Logged in with \(id)")
///     Log.assert(!frame.isEmpty, "You messed it up!")
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

    fileprivate static func show(_ makeStatement: () -> LogStatement, for type: OSLogType, subsystem: String? = nil, category: String? = nil, into mirror: LogMirror? = nil, fromContainingBinary dso: UnsafeRawPointer) {
        // The system does bookkeeping of OSLog instances automatically.
        let log: OSLog
        if let subsystem = subsystem, let category = category {
            log = OSLog(subsystem: subsystem, category: category)
        } else {
            log = .default
        }

        // If neither log wants the message, do not produce the log statement.
        let nativeEnabled = log.isEnabled(type: type)

        let mirror = mirror ?? Log.mirror
        let mirrorEnabled = mirror?.isEnabled(for: type) ?? false

        guard nativeEnabled || mirrorEnabled else { return }

        // Producing the LogStatement may set the errno, f.ex for floating point.
        let retaddr = LogStatementPacker.currentReturnAddress

        // Send 0 for the errno to prevent the log message from causing a crash
        // if the errorno is not in a valid range.  We don't take advantage of the
        // errorno in our logging anyway (format specifier %m)
        let savedErrno = Int32(0)
        let statement = makeStatement()

        // Send to os_log.
        if nativeEnabled {
            LogStatementPacker.send(to: log, for: type, fromContainingBinary: dso, returnAddress: retaddr, errno: savedErrno) { (packer) -> String in
                var format = ""
                for segment in statement.segments {
                    switch segment {
                    case .literal(let string):
                        format.append(string)
                    case .string(let string):
                        format.append("%@")
                        packer.add(Unmanaged.passRetained(string as NSString).autorelease().toOpaque(), options: [])
                    case .signed(let int):
                        format.append("%zd")
                        packer.add(int, options: [])
                    case .unsigned(let int):
                        format.append("%zu")
                        packer.add(int, options: [])
                    case .float(let double, let precision):
                        format.append("%.*g")
                        packer.add(double, precision: precision, options: [])
                    case .object(let object):
                        format.append("%@")
                        packer.add(object.toOpaque(), options: [])
                    }
                }
                return format
            }
        }

        // Send to mirror.
        if mirrorEnabled, let mirror = mirror {
            mirror.show(String(describing: statement), for: type, subsystem: subsystem, category: category)
        }
    }

    /// Issues a log message at the default level.
    ///
    /// Default-level messages are initially stored in memory and moved to the
    /// data store. Use this method to capture information about things that
    /// might result in a failure.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    public static func show(_ statement: @autoclosure() -> LogStatement, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        show(statement, for: .default, fromContainingBinary: dso)
    }

    /// Issues a log message at the debug level.
    ///
    /// Debug-level messages are only captured in memory when debug logging is
    /// enabled at runtime. They are intended for use in a development
    /// environment and not in shipping software.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    public static func debug(_ statement: @autoclosure() -> LogStatement, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        show(statement, for: .debug, fromContainingBinary: dso)
    }

    /// Issues a log message at the info level.
    ///
    /// Info-level messages are initially stored in memory, but are not moved to
    /// the data store until faults or, optionally, errors occur. Use this
    /// method to capture information that may be helpful, but isn’t essential.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    public static func info(_ statement: @autoclosure() -> LogStatement, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        show(statement, for: .info, fromContainingBinary: dso)
    }

    /// Issues a log message at the error level.
    ///
    /// Error-level messages are always saved in the data store.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    public static func error(_ statement: @autoclosure() -> LogStatement, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        show(statement, for: .error, fromContainingBinary: dso)
    }

    /// Issues a log message at the fault level.
    ///
    /// Fault-level messages are always saved in the data store.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    public static func fault(_ statement: @autoclosure() -> LogStatement, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        show(statement, for: .default, fromContainingBinary: dso)
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
    public static func trace(function: StaticString = #function, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        debug("\(function)", fromContainingBinary: dso)
    }

    /// Issues a log message at the info level indicating that a sanity check
    /// failed.
    ///
    /// Use this method during development to check for invalid usage. In
    /// playgrounds or -Onone builds (the default for Xcode's Debug
    /// configuration), program execution will be stopped in a debuggable state.
    /// To fail similarly in Release builds, see `preconditionFailure`.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message` in a playground
    ///   or `-Onone` build.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information.
    public static func assertionFailure(_ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        let mirror = AssertionFailureMirror(file: file, line: line)
        show(statement, for: .info, into: mirror, fromContainingBinary: dso)
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
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message` in a playground
    ///   or `-Onone` build. The default is the file where the assertion failed.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build. The default is the line where the
    ///   assertion failed.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   assertion failed.
    @_transparent // makes failures use the DEBUG of calling code
    public static func assert(_ condition: @autoclosure() -> Bool, _ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        guard !condition() else { return }
        assertionFailure(statement, file: file, line: line, fromContainingBinary: dso)
    }

    /// Issues a log message at the error level indicating that a precondition
    /// was violated.
    ///
    /// Use this method to stop the program when control flow can only reach the
    /// call if your API was improperly used. Program execution will be stopped.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message`.
    /// - parameter line: The line number to print along with `message`.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information.
    public static func preconditionFailure(_ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) -> Never {
        let mirror = PreconditionFailureMirror(file: file, line: line)
        show(statement, for: .error, into: mirror, fromContainingBinary: dso)
        Swift.preconditionFailure("can't get here")
    }

    /// Checks a necessary condition for making forward progress. If it fails,
    /// a log message is issued at the error level.
    ///
    /// Use this method to stop the program when control flow can only reach the
    /// call if your API was improperly used. Error-level messages are always
    /// saved in the data store. Program execution will be stopped.
    ///
    /// - parameter condition: The condition to test. It is always evaluated.
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message`. The default is
    ///   the file where the precondition failed.
    /// - parameter line: The line number to print along with `message`. The
    ///   default is the line where the precondition failed.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   precondition failed.
    @_transparent // makes failures use the DEBUG of calling code
    public static func precondition(_ condition: @autoclosure() -> Bool, _ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        guard !condition() else { return }
        preconditionFailure(statement, file: file, line: line, fromContainingBinary: dso)
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
///             Log.network.error("Could not log in: \(error)")
///         }
///     }
///
public protocol LogSubsystem {
    /// The name of a subsystem, such as "networking".
    static var name: String { get }

    /// A stage or grouping for a subsystem, such as "setup" or "teardown".
    var categoryName: String { get }

    /// Whether to print messages in this category.
    func isEnabled(for type: OSLogType) -> Bool
}

extension LogSubsystem {

    /// By default, the description of `Self`.
    public static var name: String {
        return String(reflecting: self)
    }

    /// By default, the description of `self`.
    public var categoryName: String {
        return String(describing: self)
    }

    /// By default, all subsystems are enabled at the code level, but some
    /// levels may be disabled at runtime.
    public func isEnabled(for type: OSLogType) -> Bool {
        return true
    }

    /// Issues a log message at the default level.
    ///
    /// Default-level messages are initially stored in memory and moved to the
    /// data store. Use this method to capture information about things that
    /// might result in a failure.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    public func show(_ statement: @autoclosure() -> LogStatement, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        guard isEnabled(for: .default) else { return }
        Log.show(statement, for: .default, subsystem: Self.name, category: categoryName, fromContainingBinary: dso)
    }

    /// Issues a log message at the debug level.
    ///
    /// Debug-level messages are only captured in memory when debug logging is
    /// enabled at runtime. They are intended for use in a development
    /// environment and not in shipping software.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    public func debug(_ statement: @autoclosure() -> LogStatement, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        guard isEnabled(for: .debug) else { return }
        Log.show(statement, for: .debug, subsystem: Self.name, category: categoryName, fromContainingBinary: dso)
    }

    /// Issues a log message at the info level.
    ///
    /// Info-level messages are initially stored in memory, but are not moved to
    /// the data store until faults or, optionally, errors occur. Use this
    /// method to capture information that may be helpful, but isn’t essential.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    public func info(_ statement: @autoclosure() -> LogStatement, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        guard isEnabled(for: .info) else { return }
        Log.show(statement, for: .info, subsystem: Self.name, category: categoryName, fromContainingBinary: dso)
    }

    /// Issues a log message at the error level.
    ///
    /// Error-level messages are always saved in the data store.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    public func error(_ statement: @autoclosure() -> LogStatement, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        guard isEnabled(for: .error) else { return }
        Log.show(statement, for: .error, subsystem: Self.name, category: categoryName, fromContainingBinary: dso)
    }

    /// Issues a log message at the fault level.
    ///
    /// Fault-level messages are always saved in the data store.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    public func fault(_ statement: @autoclosure() -> LogStatement, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        guard isEnabled(for: .fault) else { return }
        Log.show(statement, for: .fault, subsystem: Self.name, category: categoryName, fromContainingBinary: dso)
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
    public func trace(function: StaticString = #function, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        debug("\(function)", fromContainingBinary: dso)
    }

    /// Issues a log message at the info level indicating that a sanity check
    /// failed.
    ///
    /// Use this method during development to check for invalid usage. In
    /// playgrounds or -Onone builds (the default for Xcode's Debug
    /// configuration), program execution will be stopped in a debuggable state.
    /// To fail similarly in Release builds, see `preconditionFailure`.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message` in a playground
    ///   or `-Onone` build.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information.
    public func assertionFailure(_ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        let mirror = AssertionFailureMirror(file: file, line: line)
        Log.show(statement, for: .error, subsystem: Self.name, category: categoryName, into: mirror, fromContainingBinary: dso)
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
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message` in a playground
    ///   or `-Onone` build. The default is the file where the assertion failed.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build. The default is the line where the
    ///   assertion failed.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   assertion failed.
    @_transparent // makes failures use the DEBUG of calling code
    public func assert(_ condition: @autoclosure() -> Bool, _ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        guard !condition() else { return }
        assertionFailure(statement(), file: file, line: line, fromContainingBinary: dso)
    }

    /// Issues a log message at the error level indicating that a precondition
    /// was violated.
    ///
    /// Use this method to stop the program when control flow can only reach the
    /// call if your API was improperly used. Program execution will be stopped.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message`.
    /// - parameter line: The line number to print along with `message`.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information.
    public func preconditionFailure(_ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) -> Never {
        let mirror = PreconditionFailureMirror(file: file, line: line)
        Log.show(statement, for: .fault, subsystem: Self.name, category: categoryName, into: mirror, fromContainingBinary: dso)
        Swift.preconditionFailure("can't get here")
    }

    /// Checks a necessary condition for making forward progress. If it fails,
    /// a log message is issued at the error level.
    ///
    /// Use this method to stop the program when control flow can only reach the
    /// call if your API was improperly used. Error-level messages are always
    /// saved in the data store. Program execution will be stopped.
    ///
    /// - parameter condition: The condition to test. It is always evaluated.
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message`. The default is
    ///   the file where the precondition failed.
    /// - parameter line: The line number to print along with `message`. The
    ///   default is the line where the precondition failed.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   precondition failed.
    @_transparent // makes failures use the DEBUG of calling code
    public func precondition(_ condition: @autoclosure () -> Bool, _ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, fromContainingBinary dso: UnsafeRawPointer = #dsohandle) {
        guard !condition() else { return }
        preconditionFailure(statement(), file: file, line: line, fromContainingBinary: dso)
    }

}

/// A simple, named category for logs.
///
/// A typical use is for file-based logging:
///
///     private let Log = AppLogCategory(name: "imageCache")
///
///     extension MyImageCache {
///         func logFailure(_ error: Error) {
///             Log.error("Could not log in: \(error)")
///         }
///     }
///
public struct AppLogCategory: LogSubsystem {

    public static var name: String {
        return Bundle.main.bundleIdentifier ?? "unknown"
    }

    public let categoryName: String
    public init(name categoryName: String) {
        self.categoryName = categoryName
    }

}

// MARK: - Log mirroring

/// A type that may be used as a secondary target for log subsystems.
///
/// - seealso: Log.mirror
public protocol LogMirror {
    /// Return `true` if `show` should be invoked for this mirror. Return
    /// `false` to potentially save resources if the message is to be ignored.
    func isEnabled(for type: OSLogType) -> Bool

    /// Record a formatted log `message`. Structural information, such as
    /// `type`, `subsystem`, and `category` are passed to enhance log output.
    func show(_ message: String, for type: OSLogType, subsystem: String?, category: String?)
}

extension LogMirror {

    /// By default, all subsystems are mirrored.
    public func isEnabled(for type: OSLogType) -> Bool {
        return true
    }

}

private struct AssertionFailureMirror: LogMirror {
    let file: StaticString
    let line: UInt

    func show(_ message: String, for _: OSLogType, subsystem _: String?, category _: String?) {
        assertionFailure(message, file: file, line: line)
    }
}

private struct PreconditionFailureMirror: LogMirror {
    let file: StaticString
    let line: UInt

    func show(_ message: String, for _: OSLogType, subsystem _: String?, category _: String?) {
        preconditionFailure(message, file: file, line: line)
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

// swiftlint:enable file_length
