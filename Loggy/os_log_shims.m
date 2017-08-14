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

#include "os_log_shims_private.h"
#include <os/overflow.h>
#include <unistd.h>

// MARK: - Blob

void os_trace_blob_destroy_slow(__loggy_os_log_blob_t ob) {
    void *s = ob->ob_b;
    ob->ob_b = (uint8_t *)0xEBADF000;
    ob->ob_flags = 0;
    free(s);
}

static uint32_t os_trace_blob_grow(__loggy_os_log_blob_t ob, size_t hint) {
    uint32_t size, minsize, used = ob->ob_len + !ob->ob_binary;
    if (os_add_overflow(used, hint, &minsize)) {
        size = ob->ob_maxsize;
    } else if (os_mul_overflow(ob->ob_size, 2, &size)) {
        size = ob->ob_maxsize;
    } else {
        minsize = minsize > size ? minsize : size;
        size = ob->ob_maxsize < minsize ? ob->ob_maxsize : minsize;
    }

    if (size > ob->ob_size) {
        if (ob->ob_flags & OS_TRACE_BLOB_NEEDS_FREE) {
            ob->ob_b = realloc(ob->ob_b, size);
        } else {
            void *s = ob->ob_b;
            ob->ob_b = malloc(size);
            memcpy(ob->ob_b, s, used);
            ob->ob_flags |= OS_TRACE_BLOB_NEEDS_FREE;
        }
        ob->ob_size = size;
    }

    return size - used;
}

uint32_t os_trace_blob_add_slow(__loggy_os_log_blob_t ob, const void *ptr, size_t size) {
    if (OS_EXPECT(!!(ob->ob_flags & OS_TRACE_BLOB_TRUNCATED), 0)) {
        return 0;
    }

    uint32_t avail = _os_trace_blob_available(ob);
    if (avail < size) {
        if (ob->ob_size < ob->ob_maxsize) {
            avail = os_trace_blob_grow(ob, size);
        }
        if (avail < size) {
            ob->ob_flags |= OS_TRACE_BLOB_TRUNCATED;
            size = avail;
        }
    }

    memcpy(ob->ob_b + ob->ob_len, ptr, size);
    return _os_trace_blob_growlen(ob, size);
}

// MARK: - Log buffer

#define OST_FORMAT_MAX_STRING_SIZE 1024
#define OS_LOG_FMT_MAX_CMDS    48
#define OS_LOG_FMT_BUF_SIZE    (2 + (2 + 16) * OS_LOG_FMT_MAX_CMDS)

OS_OPTIONS(os_log_fmt_hdr_flags, uint8_t,
    OSLF_HDR_FLAG_HAS_PRIVATE = 0x01,
    OSLF_HDR_FLAG_HAS_NON_SCALAR = 0x02,
);

typedef struct __loggy_os_log_fmt_hdr_s {
    os_log_fmt_hdr_flags_t hdr_flags;
    uint8_t hdr_cmd_cnt;
} os_log_fmt_hdr_s;

OS_ENUM(os_log_fmt_cmd_type, uint8_t,
    OSLF_CMD_TYPE_SCALAR = 0,
    OSLF_CMD_TYPE_COUNT = 1,
    OSLF_CMD_TYPE_STRING = 2,
    OSLF_CMD_TYPE_DATA = 3,
    OSLF_CMD_TYPE_OBJECT = 4,
    OSLF_CMD_TYPE_WIDE_STRING = 5,
    OSLF_CMD_TYPE_ERRNO = 6,
);

typedef struct os_log_fmt_cmd_s {
    __loggy_os_log_fmt_cmd_flags_t cmd_flags: 4;
    os_log_fmt_cmd_type_t cmd_type: 4;
    uint8_t cmd_size;
} os_log_fmt_cmd_s, *os_log_fmt_cmd_t;

typedef struct os_log_pack_s {
    uint64_t olp_continuous_time;
    struct timespec olp_wall_time;
    const void *olp_mh;
    const void *olp_pc;
    const char *olp_format;
    uint8_t olp_data[0];
} os_log_pack_s, *os_log_pack_t;

// MARK: -

static inline bool __loggy_os_log_fmt_can_add(__loggy_os_log_fmt_s fmt) {
    return fmt.header->hdr_cmd_cnt <= OS_LOG_FMT_MAX_CMDS;
}

static inline void __loggy_os_log_fmt_encode(__loggy_os_log_fmt_s fmt, os_log_fmt_cmd_t cmd, const void *data) {
    os_trace_blob_add(fmt.blob, cmd, sizeof(os_log_fmt_cmd_s));
    os_trace_blob_add(fmt.blob, data, cmd->cmd_size);

    if (cmd->cmd_flags & OSLF_CMD_FLAG_PRIVATE) {
        fmt.header->hdr_flags |= OSLF_HDR_FLAG_HAS_PRIVATE;
    }

    switch (cmd->cmd_type) {
        case OSLF_CMD_TYPE_OBJECT:
        case OSLF_CMD_TYPE_DATA:
            fmt.header->hdr_flags |= OSLF_HDR_FLAG_HAS_NON_SCALAR;
            break;
        default:
            break;
    }

    fmt.header->hdr_cmd_cnt += 1;
}

bool __loggy_os_log_fmt_add_int(__loggy_os_log_fmt_s fmt, intmax_t value, __loggy_os_log_fmt_cmd_flags_t flags) {
    if (!__loggy_os_log_fmt_can_add(fmt)) { return false; }

    os_log_fmt_cmd_s cmd = {
        .cmd_flags = flags,
        .cmd_type = OSLF_CMD_TYPE_SCALAR,
        .cmd_size = sizeof(intmax_t)
    };

    __loggy_os_log_fmt_encode(fmt, &cmd, &value);

    return true;
}

bool __loggy_os_log_fmt_add_uint(__loggy_os_log_fmt_s fmt, uintmax_t value, __loggy_os_log_fmt_cmd_flags_t flags) {
    if (!__loggy_os_log_fmt_can_add(fmt)) { return false; }

    os_log_fmt_cmd_s cmd = {
        .cmd_flags = flags,
        .cmd_type = OSLF_CMD_TYPE_SCALAR,
        .cmd_size = sizeof(uintmax_t)
    };

    __loggy_os_log_fmt_encode(fmt, &cmd, &value);

    return true;
}

bool __loggy_os_log_fmt_add_float(__loggy_os_log_fmt_s fmt, double value, int precision, __loggy_os_log_fmt_cmd_flags_t flags) {
    if (!__loggy_os_log_fmt_can_add(fmt)) { return false; }

    os_log_fmt_cmd_s cmd1 = {
        .cmd_flags = flags,
        .cmd_type = OSLF_CMD_TYPE_COUNT,
        .cmd_size = sizeof(int)
    };

    __loggy_os_log_fmt_encode(fmt, &cmd1, &precision);

    if (!__loggy_os_log_fmt_can_add(fmt)) { return false; }

    os_log_fmt_cmd_s cmd2 = {
        .cmd_flags = flags,
        .cmd_type = OSLF_CMD_TYPE_SCALAR,
        .cmd_size = sizeof(double)
    };

    __loggy_os_log_fmt_encode(fmt, &cmd2, &value);

    return true;
}

bool __loggy_os_log_fmt_add_object(__loggy_os_log_fmt_s fmt, const void *obj, __loggy_os_log_fmt_cmd_flags_t flags) {
    if (!__loggy_os_log_fmt_can_add(fmt)) { return false; }

    os_log_fmt_cmd_s cmd = {
        .cmd_flags = flags,
        .cmd_type = OSLF_CMD_TYPE_OBJECT,
        .cmd_size = sizeof(id)
    };

    __loggy_os_log_fmt_encode(fmt, &cmd, &obj);

    return true;
}

bool __loggy_os_log_fmt_add_data(__loggy_os_log_fmt_s fmt, void *data, uint8_t count, __loggy_os_log_fmt_cmd_flags_t flags) {
    if (!__loggy_os_log_fmt_can_add(fmt)) { return false; }

    os_log_fmt_cmd_s cmd = {
        .cmd_flags = flags,
        .cmd_type = OSLF_CMD_TYPE_DATA,
        .cmd_size = count
    };

    __loggy_os_log_fmt_encode(fmt, &cmd, &data);

    return true;
}

extern API_AVAILABLE(macosx(10.12.4), ios(10.3), tvos(10.2), watchos(3.2))
size_t _os_log_pack_size(size_t os_log_format_buffer_size);

extern API_AVAILABLE(macosx(10.12.4), ios(10.3), tvos(10.2), watchos(3.2))
uint8_t *_os_log_pack_fill(os_log_pack_t pack, size_t size, int saved_errno, const void *dso, const char *format);

extern API_AVAILABLE(macosx(10.12.4), ios(10.3), tvos(10.2), watchos(3.2))
void os_log_pack_send(os_log_pack_t pack, os_log_t log, os_log_type_t type);

void __loggy_os_log_pack_and_send(os_log_t oslog, os_log_type_t type, const void *dso, void *retaddr, errno_t saved_errno, NSString *(^encode)(__loggy_os_log_fmt_s fmt)) {
    uint8_t buf[OS_LOG_FMT_BUF_SIZE];
    os_log_blob_s ob = {
        .ob_b = buf,
        .ob_size = OS_LOG_FMT_BUF_SIZE,
        .ob_binary = true
    };

    os_log_fmt_hdr_s hdr = { };
    os_trace_blob_add(&ob, &hdr, sizeof(hdr));

    NSString *format = encode((__loggy_os_log_fmt_s){ .header = &hdr, .blob = &ob });
    *(__loggy_os_log_fmt_hdr_t)buf = hdr;

    if (@available(macOS 10.12.4, iOS 10.3, tvOS 10.2, watchOS 3.2, *)) {
        size_t sz = _os_log_pack_size(ob.ob_len);
        union { os_log_pack_s pack; uint8_t buf[OS_LOG_FMT_BUF_SIZE + sizeof(os_log_pack_s)]; } u;
        uint8_t *ptr = _os_log_pack_fill(&u.pack, sz, saved_errno, dso, format.UTF8String);
        u.pack.olp_pc = retaddr;
        memcpy(ptr, buf, ob.ob_len);
        os_log_pack_send(&u.pack, oslog, type);
    } else {
        _os_log_impl((void *)dso, oslog, type, format.UTF8String, buf, ob.ob_len);
    }
}
