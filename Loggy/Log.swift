//
//  Log.swift
//
//  Created by Zachary Waldowski on 9/8/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import os.log
import asl

public protocol LogSubsystem {

    static var name: String { get }
    var categoryName: String { get }

}

extension LogSubsystem {

    public static var name: String {
        return String(reflecting: self)
    }

    public var categoryName: String {
        return String(describing: self)
    }
    
}

@_silgen_name("_swift_os_log")
@available(iOS 10.0, macOS 12.0, tvOS 10.0, watchOS 3.0, *)
private func _swift_os_log(_ dso: UnsafeRawPointer?, _ log: OSLog, _ type: OSLogType, _ format: UnsafePointer<UInt8>?, _ args: CVaListPointer)

@available(iOS 10.0, macOS 12.0, tvOS 10.0, watchOS 3.0, *)
private extension OSLog {

    func show(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, level: Logger.Level, _ args: [CVarArg]) {
        guard isEnabled(type: level.logValue) else { return }

        message.withUTF8Buffer { (buf: UnsafeBufferPointer<UInt8>) in
            withVaList(args) { valist in
                _swift_os_log(dso, self, level.logValue, buf.baseAddress, valist)
            }
        }

    }

}

private struct OSTraceType: RawRepresentable, Equatable {

    var rawValue: UInt8

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    @_silgen_name("_loggy_swift_os_trace_type_error")
    static func os_trace_type_error() -> OSTraceType

    static var error: OSTraceType {
        return os_trace_type_error()
    }

    @_silgen_name("_loggy_swift_os_trace_type_fault")
    static func os_trace_type_fault() -> OSTraceType

    static var fault: OSTraceType {
        return os_trace_type_fault()
    }

    static func == (lhs: OSTraceType, rhs: OSTraceType) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

}

@_silgen_name("_loggy_swift_os_trace")
private func _swift_os_trace(_ dso: UnsafeRawPointer?, _ type: OSTraceType, _ format: UnsafePointer<UInt8>?, _ args: CVaListPointer)

private func os_trace(_ message: StaticString, dso: UnsafeRawPointer?, type: OSTraceType, _ args: [CVarArg]) {
    message.withUTF8Buffer { (buf: UnsafeBufferPointer<UInt8>) in
        withVaList(args) { valist in
            _swift_os_trace(dso, type, buf.baseAddress, valist)
        }
    }
}

private enum Logger {

    case legacy(aslclient?)
    @available(iOS 10.0, macOS 12.0, tvOS 10.0, watchOS 3.0, *)
    case native(OSLog)

    struct Provider: Hashable {

        let type: LogSubsystem.Type

        init(type: LogSubsystem.Type) {
            self.type = type
        }

        static func ==(lhs: Provider, rhs: Provider) -> Bool {
            return lhs.type == rhs.type
        }

        var hashValue: Int {
            return ObjectIdentifier(type).hashValue &* 17 &+ type.name.hashValue
        }
        
    }

    static let providerQueue = DispatchQueue(label: "Loggy.logProviderQueue")
    static var providers = [Provider: Logger]()

    static var `default`: Logger {
        if #available(iOS 10.0, macOS 12.0, tvOS 10.0, watchOS 3.0, *) {
            return .native(.default)
        } else {
            return .legacy(nil)
        }
    }

    init<T: LogSubsystem>(_ subsystem: T) {
        let key = Provider(type: T.self)
        self = Logger.providerQueue.sync {
            if let existing = Logger.providers[key] {
                return existing
            }

            let logger = Logger(subsystem: key.type.name, category: subsystem.categoryName)
            Logger.providers[key] = logger
            return logger
        }
    }

    init(subsystem: String, category: String) {
        if #available(iOS 10.0, macOS 12.0, tvOS 10.0, watchOS 3.0, *) {
            self = .native(.init(subsystem: subsystem, category: category))
        } else {
            let client = asl_open(subsystem, "com.apple.console", UInt32(ASL_OPT_STDERR))
            self = .legacy(client)
        }
    }

    enum Level: UInt8 {
        case `default` = 0x00
        case info = 0x01
        case debug = 0x02
        case error = 0x10
        case fault = 0x11

        @_transparent
        var logValue: OSLogType {
            return OSLogType(rawValue: rawValue)
        }

        @_transparent
        var aslValue: Int32 {
            switch self {
            case .default:
                return ASL_LEVEL_NOTICE
            case .info:
                return ASL_LEVEL_INFO
            case .debug:
                return ASL_LEVEL_DEBUG
            case .error:
                return ASL_LEVEL_ERR
            case .fault:
                return ASL_LEVEL_CRIT
            }
        }
    }

    func show(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, level: Level, _ args: [CVarArg]) {
        if #available(iOS 10.0, macOS 12.0, tvOS 10.0, watchOS 3.0, *), case .native(let log) = self {
            guard log.isEnabled(type: level.logValue) else { return }

            message.withUTF8Buffer { (buf: UnsafeBufferPointer<UInt8>) in
                withVaList(args) { valist in
                    _swift_os_log(dso, log, level.logValue, buf.baseAddress, valist)
                }
            }
        } else if case .legacy(let client) = self {
            switch level {
            case .default, .info, .debug:
                break
            case .error:
                os_trace(message, dso: dso, type: .error, args)
            case .fault:
                os_trace(message, dso: dso, type: .fault, args)
            }

            let text = String(format: String(describing: message), arguments: args)
            asl_vlog(client, nil, level.aslValue, text, getVaList([]))
        }
    }

}

public extension LogSubsystem {

    func show(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        Logger(self).show(message, dso: dso, level: .default, args)
    }

    func debug(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        Logger(self).show(message, dso: dso, level: .debug, args)
    }

    func info(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        Logger(self).show(message, dso: dso, level: .info, args)
    }

    func error(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        Logger(self).show(message, dso: dso, level: .error, args)
    }

    func fault(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        Logger(self).show(message, dso: dso, level: .default, args)
    }
    
}

public enum Log {

    func show(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        Logger.default.show(message, dso: dso, level: .default, args)
    }

    func debug(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        Logger.default.show(message, dso: dso, level: .debug, args)
    }

    func info(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        Logger.default.show(message, dso: dso, level: .info, args)
    }

    func error(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        Logger.default.show(message, dso: dso, level: .error, args)
    }

    func fault(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ args: CVarArg...) {
        Logger.default.show(message, dso: dso, level: .default, args)
    }
    
}
