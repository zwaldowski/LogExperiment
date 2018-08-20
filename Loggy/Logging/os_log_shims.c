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

#include "os_log_shims.h"
#include <string.h>

OS_ENUM(os_log_fmt_hdr_flags, uint8_t,
    OSLF_HDR_FLAG_HAS_PRIVATE    = 0x01,
    OSLF_HDR_FLAG_HAS_NON_SCALAR = 0x02,
);

typedef struct os_log_fmt_hdr_s {
    os_log_fmt_hdr_flags_t hdr_flags;
    uint8_t hdr_cmd_cnt;
} os_log_fmt_hdr_s, *os_log_fmt_hdr_t;

OS_ENUM(os_log_fmt_cmd_flags, uint8_t,
    OSLF_CMD_FLAG_PRIVATE = 0x1,
    OSLF_CMD_FLAG_PUBLIC = 0x2
);

OS_ENUM(os_log_fmt_cmd_type, uint8_t,
    OSLF_CMD_TYPE_SCALAR      = 0,
    OSLF_CMD_TYPE_COUNT       = 1,
    OSLF_CMD_TYPE_STRING      = 2,
    OSLF_CMD_TYPE_DATA        = 3,
    OSLF_CMD_TYPE_OBJECT      = 4,
    OSLF_CMD_TYPE_WIDE_STRING = 5,
    OSLF_CMD_TYPE_ERRNO       = 6,
);

typedef struct {
    os_log_fmt_cmd_flags_t cmd_flags : 4;
    os_log_fmt_cmd_type_t cmd_type : 4;
    uint8_t cmd_size;
} os_log_fmt_cmd_s, *os_log_fmt_cmd_t;

static inline void encode(loggy_os_log_encoder_t ob, os_log_fmt_cmd_type_t type, const void *data, size_t size) {
    os_log_fmt_hdr_t hdr = (os_log_fmt_hdr_t)ob->ob_b;
    if (ob->ob_len == 0) {
        bzero(ob->ob_b, sizeof(os_log_fmt_hdr_s));
        ob->ob_len = sizeof(os_log_fmt_hdr_s);
    }

    uint32_t avail = LOGGY_OS_LOG_ENCODER_BUF_SIZE - ob->ob_len;

    if (hdr->hdr_cmd_cnt > LOGGY_OS_LOG_ENCODER_MAX_COMMANDS || avail < sizeof(os_log_fmt_cmd_s) + size) {
        return;
    }

    os_log_fmt_cmd_s cmd = {
        .cmd_flags = 0,
        .cmd_type = type,
        .cmd_size = size
    };

    memcpy(ob->ob_b + ob->ob_len, &cmd, sizeof(os_log_fmt_cmd_s));
    ob->ob_len += sizeof(os_log_fmt_cmd_s);

    memcpy(ob->ob_b + ob->ob_len, data, size);
    ob->ob_len += size;

    if (type == OSLF_CMD_TYPE_OBJECT) {
        hdr->hdr_flags |= OSLF_HDR_FLAG_HAS_NON_SCALAR;
    }

    hdr->hdr_cmd_cnt += 1;
}

void loggy_os_log_encoder_add_int32(loggy_os_log_encoder_t encoder, int32_t value) {
    encode(encoder, OSLF_CMD_TYPE_SCALAR, &value, sizeof(int32_t));
}

void loggy_os_log_encoder_add_int64(loggy_os_log_encoder_t encoder, int64_t value) {
    encode(encoder, OSLF_CMD_TYPE_SCALAR, &value, sizeof(int64_t));
}

void loggy_os_log_encoder_add_int(loggy_os_log_encoder_t encoder, size_t value) {
    encode(encoder, OSLF_CMD_TYPE_SCALAR, &value, sizeof(size_t));
}

void loggy_os_log_encoder_add_double(loggy_os_log_encoder_t encoder, double value, int precision) {
    encode(encoder, OSLF_CMD_TYPE_SCALAR, &precision, sizeof(int));
    encode(encoder, OSLF_CMD_TYPE_SCALAR, &value, sizeof(double));
}

void loggy_os_log_encoder_add_object(loggy_os_log_encoder_t encoder, const void *value) {
    encode(encoder, OSLF_CMD_TYPE_OBJECT, &value, sizeof(void *));
}

#define OS_LOG_PACK_AVAILABILITY API_AVAILABLE(macosx(10.12.4), ios(10.3), tvos(10.2), watchos(3.2))

OS_LOG_PACK_AVAILABILITY
typedef struct os_log_pack_s {
    uint64_t        olp_continuous_time;
    struct timespec olp_wall_time;
    const void     *olp_mh;
    const void     *olp_pc;
    const char     *olp_format;
    uint8_t         olp_data[0];
} os_log_pack_s, *os_log_pack_t;

OS_LOG_PACK_AVAILABILITY
extern size_t _os_log_pack_size(size_t os_log_format_buffer_size);

OS_LOG_PACK_AVAILABILITY
extern uint8_t *_os_log_pack_fill(os_log_pack_t pack, size_t size, int saved_errno, const void *dso, const char *fmt);

OS_LOG_PACK_AVAILABILITY
extern void os_log_pack_send(os_log_pack_t pack, os_log_t log, os_log_type_t type);

void loggy_os_log_send(loggy_os_log_encoder_t encoder, const char *fmt, os_log_t h, os_log_type_t type, const void *ra, const void *dso) {
    if (__builtin_available(macOS 10.12.4, iOS 10.3, tvOS 10.2, watchOS 3.2, *)) {
        size_t sz = _os_log_pack_size(encoder->ob_len);
        uint8_t buf[sz];
        uint8_t *ptr = _os_log_pack_fill((os_log_pack_t)buf, sz, 0, dso, fmt);
        ((os_log_pack_t)buf)->olp_pc = ra;
        memcpy(ptr, encoder->ob_b, encoder->ob_len);
        os_log_pack_send((os_log_pack_t)buf, h, type);
    } else {
        _os_log_impl((void *)dso, h, type, fmt, encoder->ob_b, encoder->ob_len);
    }
}

#if LOGGY_HAS_OS_SIGNPOST

LOGGY_OS_SIGNPOST_AVAILABILITY
extern uint8_t *_os_signpost_pack_fill(os_log_pack_t pack, size_t size, int saved_errno, const void *dso, const char *fmt, const char *spnm, os_signpost_id_t spid);

LOGGY_OS_SIGNPOST_AVAILABILITY
extern void _os_signpost_pack_send(os_log_pack_t pack, os_log_t h, os_signpost_type_t spty);

void loggy_os_signpost_send(loggy_os_log_encoder_t encoder, const char *fmt, os_log_t h, os_signpost_type_t spty, const uint8_t *spnm, os_signpost_id_t spid, const void *ra, const void *dso) {
    size_t sz = _os_log_pack_size(encoder->ob_len);
    uint8_t buf[sz];
    uint8_t *ptr = _os_signpost_pack_fill((os_log_pack_t)buf, sz, 0, dso, fmt, (const char *)spnm, spid);
    ((os_log_pack_t)buf)->olp_pc = ra;
    memcpy(ptr, encoder->ob_b, encoder->ob_len);
    _os_signpost_pack_send((os_log_pack_t)buf, h, spty);
}

#endif
