//
//  Activity.swift
//
//  Created by Zachary Waldowski on 8/21/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import os.activity

@available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *)
private let os_activity_create: @convention(c) (UnsafeRawPointer?, UnsafePointer<Int8>?, AnyObject?, os_activity_flag_t) -> AnyObject = DynamicLibrary.default.symbol(named: "_os_activity_create")

@available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *)
private let os_activity_apply: @convention(c) (AnyObject, (Void) -> ()) -> () = DynamicLibrary.default.symbol(named: "os_activity_apply")

@available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *)
private let os_activity_scope_enter: @convention(c) (AnyObject, UnsafeMutablePointer<os_activity_scope_state_s>) -> () = DynamicLibrary.default.symbol(named: "os_activity_scope_enter")

@available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *)
private let os_activity_scope_leave: @convention(c) (UnsafeMutablePointer<os_activity_scope_state_s>) -> () = DynamicLibrary.default.symbol(named: "os_activity_scope_leave")

@available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *)
private let OS_ACTIVITY_NONE: Unmanaged<AnyObject> = DynamicLibrary.default.symbol(named: "_os_activity_none")

@available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *)
private let OS_ACTIVITY_CURRENT: Unmanaged<AnyObject> = DynamicLibrary.default.symbol(named: "_os_activity_current")

public struct Activity {

    /// Support flags for Activity.
    public struct Options: OptionSet {
        public let rawValue: UInt32
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Detach a newly created activity from a parent activity, if any.
        ///
        /// If passed in conjunction with a parent activity, the activity will
        /// only note what activity "created" the new one, but will make the
        /// new activity a top level activity. This allows seeing what
        /// activity triggered work without actually relating the activities.
        public static let detached = Options(rawValue: OS_ACTIVITY_FLAG_DETACHED.rawValue)

        /// Will only create a new activity if none present.
        ///
        /// If an activity ID is already present, a new activity will be
        /// returned with the same underlying activity ID.
        @available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *)
        public static let ifNonePresent = Options(rawValue: OS_ACTIVITY_FLAG_IF_NONE_PRESENT.rawValue)
    }

    private let opaque: AnyObject

    /// Creates an activity.
    public init(_ description: StaticString, dso: UnsafeRawPointer? = #dsohandle, options: Options = []) {
        self.opaque = description.withUTF8Buffer { (buffer: UnsafeBufferPointer<UInt8>) -> AnyObject in
            assert(OS_ACTIVITY_OBJECT_API != 0)

            let string = UnsafeRawPointer(buffer.baseAddress)?.assumingMemoryBound(to: Int8.self)
            let flags = os_activity_flag_t(rawValue: options.rawValue)
            return os_activity_create(dso, string, Activity.current.opaque, flags)
        }
    }

    private func withActive(execute body: (Void) -> ()) {
        assert(OS_ACTIVITY_OBJECT_API != 0)
        os_activity_apply(opaque, body)
    }

    /// Executes a function body within the context of the activity.
    public func withActive<Return>(execute body: () throws -> Return) rethrows -> Return {
        func impl(execute work: () throws -> Return, recover: (Error) throws -> Return) rethrows -> Return {
            var result: Return?
            var error: Error?
            withActive {
                do {
                    result = try work()
                } catch let e {
                    error = e
                }
            }
            if let e = error {
                return try recover(e)
            } else {
                return result!
            }

        }

        return try impl(execute: body, recover: { throw $0 })
    }

    /// Opaque structure created by `Activity.enter()` and restored using
    /// `leave()`.
    public struct Scope {
        fileprivate var state = os_activity_scope_state_s()
        fileprivate init() {}

        /// Pops activity state to `self`.
        public mutating func leave() {
            assert(OS_ACTIVITY_OBJECT_API != 0)
            os_activity_scope_leave(&state)
        }
    }

    /// Changes the current execution context to the activity.
    ///
    /// An activity can be created and applied to the current scope by doing:
    ///
    ///    var scope = Activity("my new activity").enter()
    ///    defer { scope.leave() }
    ///    ... do some work ...
    ///
    public func enter() -> Scope {
        assert(OS_ACTIVITY_OBJECT_API != 0)

        var scope = Scope()
        os_activity_scope_enter(opaque, &scope.state)
        return scope
    }

    /// Creates an activity.
    @available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *)
    public init(_ description: StaticString, dso: UnsafeRawPointer? = #dsohandle, parent: Activity, options: Options = []) {
        self.opaque = description.withUTF8Buffer { (buffer: UnsafeBufferPointer<UInt8>) -> AnyObject in
            let string = UnsafeRawPointer(buffer.baseAddress)?.assumingMemoryBound(to: Int8.self)
            let flags = os_activity_flag_t(rawValue: options.rawValue)
            return os_activity_create(dso, string, parent.opaque, flags)
        }
    }

    private init(_ opaque: AnyObject) {
        self.opaque = opaque
    }

    /// An activity with no traits; as a parent, it is equivalent to a
    /// detached activity.
    @available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *)
    public static var none: Activity {
        return Activity(OS_ACTIVITY_NONE.takeUnretainedValue())
    }

    /// The running activity.
    ///
    /// As a parent, the new activity is linked to the current activity, if one
    /// is present. If no activity is present, it behaves the same as `.none`.
    @available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *)
    public static var current: Activity {
        return Activity(OS_ACTIVITY_CURRENT.takeUnretainedValue())
    }

    /// Label an activity auto-generated by UI with a name that is useful for
    /// debugging macro-level user actions.
    ///
    /// This function should be called early within the scope of an `IBAction`,
    /// before any sub-activities are created. The name provided will be shown
    /// in tools in addition to the system-provided name. This API should only
    /// be called once, and only on an activity created by the system. These
    /// actions help determine workflow of the user in order to reproduce
    /// problems that occur.
    ///
    /// For example, a control press and/or menu item selection can be labeled:
    ///
    ///    Activity.labelUserAction("New mail message")
    ///    Activity.labelUserAction("Empty trash")
    ///
    /// Where the underlying name will be "gesture:" or "menuSelect:".
    public static func labelUserAction(_ description: StaticString, dso: UnsafeRawPointer = #dsohandle) {
        description.withUTF8Buffer { (buffer: UnsafeBufferPointer<UInt8>) in
            let string = UnsafeRawPointer(buffer.baseAddress)!.assumingMemoryBound(to: Int8.self)
            _os_activity_label_useraction(UnsafeMutableRawPointer(mutating: dso), string)
        }
    }
    
}
