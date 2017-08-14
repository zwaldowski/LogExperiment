//
//  Loggy.h
//
//  Created by Zachary Waldowski on 9/8/16.
//  Copyright © 2016-2017 Big Nerd Ranch. Licensed under MIT.
//

@import os.activity;

extern const void * _Nullable _swift_os_log_return_address(void);

extern void _swift_os_log(const void *_Nonnull dso, const void *_Nullable retaddr, os_log_t _Nonnull oslog, os_log_type_t type, const uint8_t *_Nullable format, va_list args);
#include <Loggy/os_activity_shims.h>
