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

#ifndef __loggy_os_log_shims_h__
#define __loggy_os_log_shims_h__

#include <os/log.h>
#include <Foundation/Foundation.h>

#ifndef OS_OPTIONS
#define OS_OPTIONS(_name, _type, ...) \
        typedef NS_OPTIONS(_type, _name##_t) { __VA_ARGS__ }
#endif

OS_ASSUME_NONNULL_BEGIN

typedef struct __loggy_os_log_fmt_hdr_s *__loggy_os_log_fmt_hdr_t;
typedef struct __loggy_os_log_blob_s *__loggy_os_log_blob_t;

typedef struct {
    __loggy_os_log_fmt_hdr_t header;
    __loggy_os_log_blob_t blob;
} __loggy_os_log_fmt_s OS_SWIFT_NAME(LogStatementPacker);

OS_OPTIONS(__loggy_os_log_fmt_cmd_flags, uint8_t,
    OSLF_CMD_FLAG_PRIVATE OS_SWIFT_NAME(private) = 0x1,
    OSLF_CMD_FLAG_PUBLIC OS_SWIFT_NAME(public) = 0x2,
) OS_SWIFT_NAME(LogStatementPacker.Options);

OS_SWIFT_NAME(LogStatementPacker.add(self:_:options:))
bool __loggy_os_log_fmt_add_int(__loggy_os_log_fmt_s fmt, intmax_t value, __loggy_os_log_fmt_cmd_flags_t flags);

OS_SWIFT_NAME(LogStatementPacker.add(self:_:options:))
bool __loggy_os_log_fmt_add_uint(__loggy_os_log_fmt_s fmt, uintmax_t value, __loggy_os_log_fmt_cmd_flags_t flags);

OS_SWIFT_NAME(LogStatementPacker.add(self:_:precision:options:))
bool __loggy_os_log_fmt_add_float(__loggy_os_log_fmt_s fmt, double value, int precision, __loggy_os_log_fmt_cmd_flags_t flags);

OS_SWIFT_NAME(LogStatementPacker.add(self:_:options:))
bool __loggy_os_log_fmt_add_object(__loggy_os_log_fmt_s fmt, const void *_Nullable obj, __loggy_os_log_fmt_cmd_flags_t flags);

OS_SWIFT_NAME(LogStatementPacker.add(self:bytesFrom:count:options:))
bool __loggy_os_log_fmt_add_data(__loggy_os_log_fmt_s fmt, void *_Nullable data, uint8_t count, __loggy_os_log_fmt_cmd_flags_t flags);

OS_ALWAYS_INLINE OS_INLINE OS_SWIFT_NAME(getter:LogStatementPacker.currentReturnAddress())
void *_Nullable __loggy_os_log_return_address(void) {
    return __builtin_return_address(1);
}

OS_SWIFT_NAME(LogStatementPacker.send(to:for:fromContainingBinary:returnAddress:errno:byCreatingFormat:))
void __loggy_os_log_pack_and_send(os_log_t oslog, os_log_type_t type, const void *dso, void *_Nullable retaddr, errno_t saved_errno, NSString *(^OS_NOESCAPE encode)(__loggy_os_log_fmt_s fmt));

OS_ASSUME_NONNULL_END

#endif /* __loggy_os_log_shims_h__ */

