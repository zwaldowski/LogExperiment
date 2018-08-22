//
//  OSLog+AppCategory.swift
//  Loggy
//
//  Created by Zachary Waldowski on 8/22/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

import Foundation

private extension Bundle {

    static let cache = NSCache<NSValue, Bundle>()

    static func containing(_ dso: UnsafeRawPointer) -> Bundle {
        let cacheKey = NSValue(pointer: dso)
        if let bundle = cache.object(forKey: cacheKey) {
            return bundle
        }

        var info = Dl_info()
        guard dladdr(dso, &info) != 0 else { return .main }

        var url = URL(fileURLWithFileSystemRepresentation: info.dli_fname, isDirectory: false, relativeTo: nil)

        for _ in 0 ..< 3 {
            url.deleteLastPathComponent()

            guard let bundle = Bundle(url: url) else { continue }
            cache.setObject(bundle, forKey: cacheKey)
            return bundle
        }

        return .main
    }

}

extension OSLog {

    /// Creates a an app-specific log named `name`.
    ///
    /// In standard `OSLog` parlance, the log's `subsystem` is synthesized from
    /// the calling code's bundle identifier, and `name` is the `category`.
    public convenience init(named name: String, containingBinary dso: UnsafeRawPointer = #dsohandle) {
        let subsystem = Bundle.containing(dso).bundleIdentifier ?? ""
        self.init(subsystem: subsystem, category: name)
    }

}
