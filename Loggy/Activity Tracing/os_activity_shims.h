//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#ifndef __loggy_os_activity_shims_h__
#define __loggy_os_activity_shims_h__

#import <os/activity.h>

OS_ASSUME_NONNULL_BEGIN

OS_INLINE OS_ALWAYS_INLINE
os_activity_t loggy_os_activity_none(void) {
    return OS_ACTIVITY_NONE;
}

OS_INLINE OS_ALWAYS_INLINE
os_activity_t loggy_os_activity_current(void) {
    return OS_ACTIVITY_CURRENT;
}

OS_INLINE OS_ALWAYS_INLINE
os_activity_t loggy_os_activity_create(const void *dso, const uint8_t *_Nullable description, os_activity_t parent, os_activity_flag_t flags) {
    return _os_activity_create((void *)dso, (const char *)description, parent, flags);
}

OS_INLINE OS_ALWAYS_INLINE
void loggy_os_activity_label_useraction(const void *dso, const uint8_t *_Nullable name) {
    _os_activity_label_useraction((void *)dso, (const char *)name);
}

OS_ASSUME_NONNULL_END

#endif /* __loggy_os_activity_shims_h__ */
