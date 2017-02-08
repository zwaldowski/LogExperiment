#if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
    import Darwin
    
    private var RTLD_DEFAULT: UnsafeMutableRawPointer? {
        return UnsafeMutableRawPointer(bitPattern: -2)
    }
#elseif os(Linux)
    import Glibc
    
    private var RTLD_DEFAULT: UnsafeMutableRawPointer? {
        return UnsafeMutableRawPointer(bitPattern: 0)
    }
#endif

struct DynamicLibrary {
    private let handle: UnsafeMutableRawPointer?
    private init(handle: UnsafeMutableRawPointer?) {
        self.handle = handle
    }
    
    private static func dlerror() -> String! {
        guard let cString = Darwin.dlerror() else { return nil }
        return String(cString: UnsafePointer(cString))
    }

    public static var `default`: DynamicLibrary {
        return DynamicLibrary(handle: RTLD_DEFAULT)
    }
    
    public func symbol<T>(named name: String, of _: T.Type = T.self) -> T {
        guard let sym = dlsym(handle, name) else {
            preconditionFailure("Failed to load symbol \(name) (\(DynamicLibrary.dlerror())")
        }
        return unsafeBitCast(sym, to: T.self)
    }
}
