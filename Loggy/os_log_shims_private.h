//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#ifndef __loggy_os_log_shims_private_h__
#define __loggy_os_log_shims_private_h__

#include "os_log_shims.h"
#include <string.h>

OS_ASSUME_NONNULL_BEGIN

OS_OPTIONS(os_trace_blob_flags, uint16_t,
    OS_TRACE_BLOB_NEEDS_FREE = 0x1,
    OS_TRACE_BLOB_TRUNCATED = 0x2,
);

typedef struct __loggy_os_log_blob_s {
    uint8_t *ob_b;
    uint32_t ob_len;
    uint32_t ob_size;
    uint32_t ob_maxsize;
    os_trace_blob_flags_t ob_flags;
    bool ob_binary;
} os_log_blob_s;

#pragma mark - helpers (not to be used directly)

static inline uint32_t _os_trace_blob_available(__loggy_os_log_blob_t ob) {
    return ob->ob_size - !ob->ob_binary - ob->ob_len;
}

static inline uint32_t _os_trace_blob_growlen(__loggy_os_log_blob_t ob, size_t extra) {
    ob->ob_len += extra;
    if (!ob->ob_binary) ob->ob_b[ob->ob_len] = '\0';
    return (uint32_t)extra;
}

#pragma mark - initialization and simple helpers

static inline size_t os_trace_blob_is_empty(__loggy_os_log_blob_t ob) {
    return ob->ob_len == 0;
}

void os_trace_blob_destroy_slow(__loggy_os_log_blob_t ob);

static inline void os_trace_blob_destroy(__loggy_os_log_blob_t ob) {
    if (ob->ob_flags & OS_TRACE_BLOB_NEEDS_FREE) {
        return os_trace_blob_destroy_slow(ob);
    }
}

#pragma mark - appending to the blob

uint32_t os_trace_blob_add_slow(__loggy_os_log_blob_t ob, const void *ptr, size_t size);

static inline uint32_t os_trace_blob_add(__loggy_os_log_blob_t ob, const void *ptr, size_t size) {
    if (OS_EXPECT(!!(ob->ob_flags & OS_TRACE_BLOB_TRUNCATED), 0)) {
        return 0;
    }

    if (OS_EXPECT(size > _os_trace_blob_available(ob), 0)) {
        return os_trace_blob_add_slow(ob, ptr, size);
    }

    memcpy(ob->ob_b + ob->ob_len, ptr, size);
    return _os_trace_blob_growlen(ob, size);
}

OS_ASSUME_NONNULL_END

#endif /* __loggy_os_log_shims_private_h__ */

