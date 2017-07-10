//
//  Loggy.h
//
//  Created by Zachary Waldowski on 9/8/16.
//  Copyright © 2016-2017 Big Nerd Ranch. Licensed under MIT.
//

@import os.activity;
@import os.log;

//! Project version number for Loggy.
OS_EXPORT double LoggyVersionNumber;

//! Project version string for Loggy.
OS_EXPORT const unsigned char LoggyVersionString[];

static inline OS_ALWAYS_INLINE
os_activity_t _Nonnull
_swift_os_activity_none(void) {
    return OS_ACTIVITY_NONE;
}

static inline OS_ALWAYS_INLINE
os_activity_t _Nonnull
_swift_os_activity_current(void) {
    return OS_ACTIVITY_CURRENT;
}

extern const void * _Nullable _swift_os_log_return_address(void);

extern void _swift_os_log(const void * _Nullable dso, const void * _Nullable retaddr, os_log_t _Nonnull oslog, os_log_type_t type, const uint8_t * _Nullable format, va_list args);

