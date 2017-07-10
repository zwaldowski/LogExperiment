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
os_activity_t _Nonnull __loggy_swift_os_activity_none(void) {
    return OS_ACTIVITY_NONE;
}

static inline OS_ALWAYS_INLINE
os_activity_t _Nonnull __loggy_swift_os_activity_current(void) {
    return OS_ACTIVITY_CURRENT;
}

static inline OS_ALWAYS_INLINE
_Nonnull os_activity_t __loggy_swift_os_activity_create(const void *_Nonnull dso, const uint8_t *_Nullable description, os_activity_t _Nonnull parent, uint32_t flags) {
    return _os_activity_create((void *)dso, (const char *)description, parent, flags);
}

static inline OS_ALWAYS_INLINE
void __loggy_swift_os_activity_label_useraction(const void *_Nonnull dso, const uint8_t *_Nullable name) {
    _os_activity_label_useraction((void *)dso, (const char *)name);
}

extern const void * _Nullable _swift_os_log_return_address(void);

extern void _swift_os_log(const void *_Nonnull dso, const void *_Nullable retaddr, os_log_t _Nonnull oslog, os_log_type_t type, const uint8_t *_Nullable format, va_list args);
