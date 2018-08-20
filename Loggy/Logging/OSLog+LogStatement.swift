//
//  OSLog+LogStatement.swift
//  Loggy
//
//  Created by Zachary Waldowski on 9/8/16.
//  Copyright © 2016-2018 Big Nerd Ranch. Licensed under MIT.
//

import Foundation

extension LogStatementEncoder {

    mutating func append(_ statement: LogStatement.Variant, appendingToFormat format: inout String) {
        switch statement {
        case .literal(let string):
            format.append(string)
        case .bool(let value):
            format.append("%{bool}d")
            append(Int32(value ? 1 : 0))
        case .int8(let value):
            format.append("%hhd")
            append(Int32(value))
        case .uint8(let value):
            format.append("%hhu")
            append(Int32(value))
        case .int16(let value):
            format.append("%hd")
            append(Int32(value))
        case .uint16(let value):
            format.append("%hu")
            append(Int32(value))
        case .int32(let value):
            format.append("%d")
            append(value)
        case .uint32(let value):
            format.append("%u")
            append(Int32(bitPattern: value))
        case .int64(let value):
            format.append("%lld")
            append(value)
        case .uint64(let value):
            format.append("%llu")
            append(Int64(bitPattern: value))
        case .int(let value):
            format.append("%zd")
            append(value)
        case .uint(let value):
            format.append("%zu")
            append(Int(bitPattern: value))
        case .float(let value):
            format.append("%.*g")
            append(Double(value), precision: FLT_DIG)
        case .double(let value):
            format.append("%.*g")
            append(value, precision: DBL_DIG)
        case .string(let value):
            format.append("%@")
            let object = Unmanaged.passRetained(value as NSString).autorelease()
            append(object.toOpaque())
        case .object(let object):
            format.append("%@")
            append(object.toOpaque())
        case .multiple(let others):
            for other in others {
                append(other, appendingToFormat: &format)
            }
        }
    }

    mutating func send(format: String, to log: OSLog, at type: OSLogType, fromAddress ra: UnsafeRawPointer, containingBinary dso: UnsafeRawPointer) {
        format.withCString { (formatPtr) in
            __send(format: formatPtr, to: log, at: type, fromAddress: ra, containingBinary: dso)
        }
    }

}

extension OSLog {

    @_versioned
    @discardableResult
    func show(_ type: OSLogType, makingStatementUsing makeStatement: () -> LogStatement, containingBinary dso: UnsafeRawPointer) -> LogStatement? {
        // If the log does not want the message, do not produce the log statement.
        guard isEnabled(type: type) else { return nil }

        // The instrumentation performed by os_log should not include this
        // function or any it calls in the course of building the log buffer.
        let retaddr = LogStatementEncoder.currentReturnAddress

        // Now we're ready to build up the string literal.
        let statement = makeStatement()

        var format = ""
        var encoder = LogStatementEncoder()
        encoder.append(statement.variant, appendingToFormat: &format)
        encoder.send(format: format, to: self, at: type, fromAddress: retaddr, containingBinary: dso)

        return statement
    }

    /// Issues a log message at the default level.
    ///
    /// Default-level messages are initially stored in memory and moved to the
    /// data store. Use this function to capture information about things that
    /// might result in a failure.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    @_inlineable
    public func show(_ statement: @autoclosure() -> LogStatement, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        show(.default, makingStatementUsing: statement, containingBinary: dso)
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
    @_inlineable
    public func debug(_ statement: @autoclosure() -> LogStatement, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        show(.debug, makingStatementUsing: statement, containingBinary: dso)
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
    @_inlineable
    public func info(_ statement: @autoclosure() -> LogStatement, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        show(.info, makingStatementUsing: statement, containingBinary: dso)
    }

    /// Issues a log message at the error level.
    ///
    /// Error-level messages are always saved in the data store.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    @_inlineable
    public func error(_ statement: @autoclosure() -> LogStatement, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        show(.error, makingStatementUsing: statement, containingBinary: dso)
    }

    /// Issues a log message at the fault level.
    ///
    /// Fault-level messages are always saved in the data store.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    @_inlineable
    public func fault(_ statement: @autoclosure() -> LogStatement, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        show(.fault, makingStatementUsing: statement, containingBinary: dso)
    }

    /// Issues a log message at the default level.
    ///
    /// Default-level messages are initially stored in memory and moved to the
    /// data store. Use this function to capture information about things that
    /// might result in a failure.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    @_inlineable
    public static func show(_ statement: @autoclosure() -> LogStatement, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        self.default.show(statement, containingBinary: dso)
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
    @_inlineable
    public static func debug(_ statement: @autoclosure() -> LogStatement, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        self.default.debug(statement, containingBinary: dso)
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
    @_inlineable
    public static func info(_ statement: @autoclosure() -> LogStatement, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        self.default.info(statement, containingBinary: dso)
    }

    /// Issues a log message at the error level.
    ///
    /// Error-level messages are always saved in the data store.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    @_inlineable
    public static func error(_ statement: @autoclosure() -> LogStatement, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        self.default.error(statement, containingBinary: dso)
    }

    /// Issues a log message at the fault level.
    ///
    /// Fault-level messages are always saved in the data store.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   extra debugging information. The default is the module where the
    ///   log message was sent.
    @_inlineable
    public static func fault(_ statement: @autoclosure() -> LogStatement, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        self.default.fault(statement, containingBinary: dso)
    }

}

// MARK: - Conveniences

extension OSLog {

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
    @_inlineable
    public func trace(function: StaticString = #function, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        self.debug("\(function)", containingBinary: dso)
    }

}

// MARK: - Assertions

extension OSLog {

    /// Issues a log message at the default level indicating that a sanity check
    /// failed.
    ///
    /// Use this method during development to notify upon invalid usage. In
    /// playgrounds or -Onone builds (the default for Xcode's Debug
    /// configuration), program execution will be stopped in a debuggable state.
    /// To fail similarly in Release builds, see `preconditionFailure(_:file:line:containingBinary:)`.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message` in a playground
    ///   or `-Onone` build.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   assertion failed.
    @_inlineable
    public func assertionFailure(_ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        let statement = show(.default, makingStatementUsing: statement, containingBinary: dso) ?? statement()
        Swift.assertionFailure("\(statement)", file: file, line: line)
    }

    /// Performs a sanity check. If it fails, a log message is issued at the
    /// info level.
    ///
    /// Use this function for internal sanity checks that are active during
    /// testing but do not impact performance of shipping code. In playgrounds
    /// and -Onone builds (the default for Xcode's Debug configuration), failing
    /// the check will stop program execution in a debuggable state. To fail
    /// similarly in Release builds, see `precondition(_:_:file:line:containingBinary:)`.
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
    ///   assertion is checked.
    @_transparent
    public func assert(_ condition: @autoclosure() -> Bool, _ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        guard _isDebugAssertConfiguration(), !condition() else { return }
        assertionFailure(statement(), file: file, line: line, containingBinary: dso)
    }

    /// Issues a log message at the error level indicating that a precondition
    /// was violated.
    ///
    /// Use this function to stop the program when control flow can only reach
    /// the call if your API was improperly used. Program execution will be
    /// stopped in a debuggable state after issuing the log message. Error-level
    /// messages are always saved in the data store.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message`.
    /// - parameter line: The line number to print along with `message`.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   precondition failed.
    @_inlineable
    public func preconditionFailure(_ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle) -> Never {
        let statement = show(.error, makingStatementUsing: statement, containingBinary: dso) ?? statement()
        Swift.preconditionFailure("\(statement)", file: file, line: line)
    }

    /// Checks a necessary condition for making forward progress. If it fails,
    /// a log message is issued at the error level.
    ///
    /// Use this function to stop the program when control flow can only reach
    /// the call if your API was improperly used. Program execution will be
    /// stopped in a debuggable state after issuing the log message. Error-level
    /// messages are always saved in the data store.
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
    @_transparent
    public func precondition(_ condition: @autoclosure() -> Bool, _ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        guard !condition() else { return }
        preconditionFailure(statement(), file: file, line: line, containingBinary: dso)
    }

    /// Issues a log message at the error level indicating that program must
    /// stop execution.
    ///
    /// Program execution will be stopped after issuing the log message.
    /// Error-level messages are always saved in the data store.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message`.
    /// - parameter line: The line number to print along with `message`.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   error occurred.
    @_inlineable
    public func fatalError(_ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle) -> Never {
        let statement = show(.error, makingStatementUsing: statement, containingBinary: dso) ?? statement()
        Swift.fatalError("\(statement)", file: file, line: line)
    }

    /// Issues a log message at the default level indicating that a sanity check
    /// failed.
    ///
    /// Use this method during development to notify upon invalid usage. In
    /// playgrounds or -Onone builds (the default for Xcode's Debug
    /// configuration), program execution will be stopped in a debuggable state.
    /// To fail similarly in Release builds, see `preconditionFailure(_:file:line:containingBinary:)`.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message` in a playground
    ///   or `-Onone` build.
    /// - parameter line: The line number to print along with `message` in a
    ///   playground or `-Onone` build.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   assertion failed.
    @_inlineable
    public static func assertionFailure(_ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        self.default.assertionFailure(statement, file: file, line: line, containingBinary: dso)
    }

    /// Performs a sanity check. If it fails, a log message is issued at the
    /// info level.
    ///
    /// Use this function for internal sanity checks that are active during
    /// testing but do not impact performance of shipping code. In playgrounds
    /// and -Onone builds (the default for Xcode's Debug configuration), failing
    /// the check will stop program execution in a debuggable state. To fail
    /// similarly in Release builds, see `precondition(_:_:file:line:containingBinary:)`.
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
    ///   assertion is checked.
    @_transparent
    public static func assert(_ condition: @autoclosure() -> Bool, _ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        self.default.assert(condition, statement, file: file, line: line, containingBinary: dso)
    }

    /// Issues a log message at the error level indicating that a precondition
    /// was violated.
    ///
    /// Use this function to stop the program when control flow can only reach
    /// the call if your API was improperly used. Program execution will be
    /// stopped in a debuggable state after issuing the log message. Error-level
    /// messages are always saved in the data store.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message`.
    /// - parameter line: The line number to print along with `message`.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   precondition failed.
    @_inlineable
    public static func preconditionFailure(_ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle) -> Never {
        self.default.preconditionFailure(statement, file: file, line: line, containingBinary: dso)
    }

    /// Checks a necessary condition for making forward progress. If it fails,
    /// a log message is issued at the error level.
    ///
    /// Use this function to stop the program when control flow can only reach
    /// the call if your API was improperly used. Program execution will be
    /// stopped in a debuggable state after issuing the log message. Error-level
    /// messages are always saved in the data store.
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
    @_transparent
    public static func precondition(_ condition: @autoclosure() -> Bool, _ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        self.default.precondition(condition, statement, file: file, line: line, containingBinary: dso)
    }

    /// Issues a log message at the error level indicating that program must
    /// stop execution.
    ///
    /// Program execution will be stopped after issuing the log message.
    /// Error-level messages are always saved in the data store.
    ///
    /// - parameter statement: A string literal with optional interpolation.
    /// - parameter file: The file name to print with `message`.
    /// - parameter line: The line number to print along with `message`.
    /// - parameter dso: The shared object handle, used by the OS to record
    ///   debugging information. The default is the module where the
    ///   error occurred.
    @_inlineable
    public static func fatalError(_ statement: @autoclosure() -> LogStatement, file: StaticString = #file, line: UInt = #line, containingBinary dso: UnsafeRawPointer = #dsohandle) -> Never {
        self.default.fatalError(statement, file: file, line: line, containingBinary: dso)
    }

}
