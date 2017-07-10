//
//  Loggy.h
//
//  Created by Zachary Waldowski on 9/8/16.
//  Copyright © 2016-2017 Big Nerd Ranch. Licensed under MIT.
//

@import os.activity;

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
