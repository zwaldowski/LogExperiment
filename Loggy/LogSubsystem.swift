//
//  LogSubsystem.swift
//
//  Created by Zachary Waldowski on 9/8/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import os
import struct CoreGraphics.CGFloat

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

// MARK: Log implementation

private protocol LogPointer {
    func toOpaque() -> UnsafeMutableRawPointer
}

extension OpaquePointer: LogPointer {
    fileprivate func toOpaque() -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(self)
    }
}

extension UnsafePointer: LogPointer {
    fileprivate func toOpaque() -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(mutating: self)
    }
}

extension UnsafeMutablePointer: LogPointer {
    fileprivate func toOpaque() -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(self)
    }
}

extension AutoreleasingUnsafeMutablePointer: LogPointer {
    fileprivate func toOpaque() -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(self)
    }
}

extension UnsafeRawPointer: LogPointer {
    fileprivate func toOpaque() -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(mutating: self)
    }
}

extension UnsafeMutableRawPointer: LogPointer {
    fileprivate func toOpaque() -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(self)
    }
}

extension Unmanaged: LogPointer {}

// MARK: -

private func toCCharPtr(_ p: UnsafePointer<UInt8>?) -> UnsafePointer<CChar>? {
    return p.map(UnsafeRawPointer.init)?.assumingMemoryBound(to: Int8.self)
}

private func fromCharPtr(_ p: UnsafePointer<CChar>?) -> UnsafePointer<UInt8>? {
    return p.map(UnsafeRawPointer.init)?.assumingMemoryBound(to: UInt8.self)
}

private func strchr(_ format: UnsafePointer<UInt8>?, _ scalar: UnicodeScalar) -> UnsafePointer<UInt8>? {
    return fromCharPtr(Darwin.strchr(toCCharPtr(format), Int32(scalar.value)))
}

private func strncmp(_ s1: UnsafePointer<UInt8>, _ s2: UnsafePointer<UInt8>, _ count: Int) -> Bool {
    return Darwin.strncmp(toCCharPtr(s1), toCCharPtr(s2), count) == 0
}

private func isdigit(_ c: UInt8) -> Bool {
    return Darwin.isdigit(Int32(c)) != 0
}

private extension UnicodeScalar {
    
    static func ~= (match: UnicodeScalar, ascii: UInt8) -> Bool {
        return UInt8(ascii: match) == ascii
    }
    
}

/// An `os_log` message has a compact binary representation. Ideally, it is
/// generated by the compiler, but here we are.
///
/// - see: https://github.com/apple/swift-clang/blob/stable/lib/Analysis/OSLog.cpp
private struct LogMessage {
    
    private enum Privacy: UInt8 {
        case unspecified, `private`, `public`
    }
    
    private enum Kind: UInt8 {
        case scalar = 0, count, pointer = 3, object
    }
    
    private struct Summary: OptionSet {
        let rawValue: UInt8
        
        static let hasPrivate = Summary(rawValue: 0x1)
        static let hasNonScalar = Summary(rawValue: 0x2)
    }
    
    private typealias Buffer = (UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64)
    
    private var buffer: Buffer = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

    private var contentOffset = 0
    private var argumentCount = UInt8()
    
    private mutating func rawEncode<T>(_ scalar: T, kind: Kind, privacy: Privacy, isScalar: Bool = true) -> Bool {
        let argumentLength = MemoryLayout<T>.stride
        let entrySize = (MemoryLayout<UInt8>.stride * 2) + MemoryLayout<T>.stride
        guard contentOffset + entrySize <= MemoryLayout<Buffer>.stride - (MemoryLayout<UInt8>.stride * 2) else { return false }
        
        withUnsafeMutableBytes(of: &buffer) { (buffer) in
            let entry = buffer.baseAddress!.advanced(by: (MemoryLayout<UInt8>.stride * 2) + contentOffset)
            entry.initializeMemory(as: UInt8.self, to: ((kind.rawValue & 0xF) << 4) | (privacy.rawValue & 0xF))
            (entry + 1).initializeMemory(as: UInt8.self, to: UInt8(argumentLength))
            (entry + 2).initializeMemory(as: T.self, to: scalar)
            
            if privacy == .private || !isScalar {
                var summary = buffer.load(fromByteOffset: 0, as: Summary.self)
                if privacy == .private {
                    summary.insert(.hasPrivate)
                }
                if !isScalar {
                    summary.insert(.hasNonScalar)
                }
                buffer.storeBytes(of: summary, toByteOffset: 0, as: Summary.self)
            }
        }
        
        contentOffset += entrySize
        argumentCount += 1
        
        return true
    }

    private mutating func encode(_ argument: Any, kind: Kind, privacy: Privacy) -> Bool {
        switch (kind, argument) {
        case (.scalar, let scalar as Int):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as Int8):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as Int16):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as Int32):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as Int64):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as UInt):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as UInt8):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as UInt16):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as UInt32):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as UInt64):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as Float):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as Double):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as CGFloat):
            return rawEncode(scalar, kind: kind, privacy: privacy)
        case (.scalar, let scalar as UnicodeScalar):
            return rawEncode(scalar.value, kind: kind, privacy: privacy)
        case (.pointer, let pointer as LogPointer):
            return rawEncode(pointer.toOpaque(), kind: kind, privacy: privacy, isScalar: false)
        case (.object, let value as CustomLogStringConvertible):
            let object = value.logDescription as AnyObject
            let autoreleasedPointer = Unmanaged.passRetained(object).retain().autorelease().toOpaque()
            return rawEncode(autoreleasedPointer, kind: kind, privacy: privacy, isScalar: false)
        case (.object, let value):
            let object = value as AnyObject
            let autoreleasedPointer = Unmanaged.passRetained(object).retain().autorelease().toOpaque()
            return rawEncode(autoreleasedPointer, kind: kind, privacy: privacy, isScalar: false)
        default:
            return false
        }
    }
    
    init?(format: UnsafePointer<UInt8>?, arguments: [Any], savedErrNo: errno_t = errno) {
        var format = format
        var argumentsIterator = arguments.makeIterator()
        findingSpecifiers: while var specifierHead = strchr(format, "%"), let argument = argumentsIterator.next() {
            // skip opening "%"
            specifierHead += 1

            if case "%" = specifierHead[0] {
                // Find next format after %%
                format = specifierHead + 1
                continue
            }
            
            var privacy = Privacy.unspecified
            var precision = 0
            
            parsingSpecifier: while true {
                defer { specifierHead += 1 }
                switch specifierHead[0] {
                case "l", "h", "z", "j", "t", "L", // size
                     "-", "+", " ", "#", "\'": // alignment
                    break
                
                case ".": // precision
                    if case "*" = specifierHead[1] {
                        guard rawEncode(argument, kind: .count, privacy: privacy) else { return nil }
                        specifierHead += 1
                        continue
                    }
                    
                    // we have to read the precision and do the right thing
                    var formatHead = specifierHead + 1
                    precision = 0
                    while isdigit(Int32(formatHead[0])) != 0 {
                        precision = 10 &* precision &+ Int(formatHead.pointee - UInt8(ascii: "0"))
                        formatHead += 1
                    }
                    
                    guard rawEncode(min(1024, precision), kind: .count, privacy: privacy) else { return nil }
                    
                case "{": // annotation
                    var annotationHead = specifierHead + 1
                    while annotationHead[0] != 0 {
                        defer { annotationHead += 1 }
                        
                        if case "}" = annotationHead[0] {
                            let length = annotationHead - specifierHead - 1
                            if strncmp(specifierHead + 1, "private", min(length, 7)) {
                                privacy = .private
                            } else if strncmp(specifierHead + 1, "public", min(length, 5)) {
                                privacy = .public
                            }
                            specifierHead = annotationHead
                            break
                        }
                    }
                    
                case "d", "i", "o", "u", "x", "X", // fixed point
                     "a", "A", "e", "E", "f", "F", "g", "G", // floating point
                     "c", "C": // char, wide-char
                    guard encode(argument, kind: .scalar, privacy: privacy) else { return nil }
                    format = specifierHead
                    continue findingSpecifiers
                
                case "P": // pointer data
                    // only encode a pointer if we have been given a length
                    guard precision > 0 else { break }
            
                    guard encode(argument, kind: .pointer, privacy: privacy) else { return nil }
                    precision = 0
                    format = specifierHead
                    continue findingSpecifiers
                    
                case "@": // Any
                    guard encode(argument, kind: .object, privacy: privacy) else { return nil }
                    format = specifierHead
                    continue findingSpecifiers
                    
                case "m": // errno
                    guard rawEncode(savedErrNo, kind: .scalar, privacy: privacy) else { return nil }
                    format = specifierHead
                    continue findingSpecifiers
                    
                case UInt8(ascii: "0") ... UInt8(ascii: "9"):
                    continue
                    
                default:
                    return nil
                }
            }
        }
        
        withUnsafeMutableBytes(of: &buffer) { (buffer) in
            buffer.storeBytes(of: UInt8(argumentCount), toByteOffset: 1, as: UInt8.self)
        }
    }
    
    private static let sendImpl: @convention(c) (UnsafeRawPointer?, OSLog, OSLogType, UnsafePointer<UInt8>?, UnsafePointer<UInt8>?, UInt32) -> Void = DynamicLibrary.default.symbol(named: "_os_log_impl")

    func send(format: UnsafePointer<UInt8>?, log: OSLog, level: OSLogType, dso: UnsafeRawPointer?) {
        var buffer = self.buffer
        withUnsafeBytes(of: &buffer) { (buffer) in
            LogMessage.sendImpl(dso, log, level, format, buffer.baseAddress?.assumingMemoryBound(to: UInt8.self), UInt32(contentOffset))
        }
    }
}

private extension OSLog {
    
    func show(_ message: StaticString, dso: UnsafeRawPointer?, level: OSLogType, _ arguments: [Any]) {
        guard isEnabled(type: level) else { return }

        message.withUTF8Buffer { (format: UnsafeBufferPointer<UInt8>) in
            guard let message = LogMessage(format: format.baseAddress, arguments: arguments) else { return }
            message.send(format: format.baseAddress, log: self, level: level, dso: dso)
        }
    }

}

extension LogSubsystem {
    
    private func log(_ message: StaticString, dso: UnsafeRawPointer?, level: OSLogType, _ arguments: [Any]) {
        // The system does bookkeeping of OSLog instances by subsystem and
        // category, so we don't need to deal with caching or thread-safety.
        let log = OSLog(subsystem: Self.name, category: categoryName)
        log.show(message, dso: dso, level: level, arguments)
    }
    
    public func show(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ arguments: Any...) {
        log(message, dso: dso, level: .default, arguments)
    }
    
    public func debug(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ arguments: Any...) {
        log(message, dso: dso, level: .debug, arguments)
    }
    
    public func info(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ arguments: Any...) {
        log(message, dso: dso, level: .info, arguments)
    }
    
    public func error(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ arguments: Any...) {
        log(message, dso: dso, level: .error, arguments)
    }
    
    public func fault(_ message: StaticString, dso: UnsafeRawPointer? = #dsohandle, _ arguments: Any...) {
        log(message, dso: dso, level: .fault, arguments)
    }
    
    public func trace(function: StaticString = #function, dso: UnsafeRawPointer? = #dsohandle) {
        log(function, dso: dso, level: .debug, [])
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
