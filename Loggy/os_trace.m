#include <os/trace.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>

enum os_trace_int_types_t {
	T_CHAR		= -2,
	T_SHORT		= -1,
	T_INT		=  0,
	T_LONG		=  1,
	T_LONGLONG	=  2,
	T_SIZE		=  3,
	T_INTMAX	=  4,
	T_PTRDIFF	=  5,
};

typedef struct os_trace_format_value_s {
    union {
        char		ch;
        short		s;
        int			i;
        wchar_t		wch;
        size_t		z;
        intmax_t	im;
        ptrdiff_t	pd;
        long		l;
        long long	ll;
        double		d;
        float		f;
        long double ld;
    } type;
	uint16_t size;
} *os_trace_format_value_t;

typedef struct os_trace_buffer_context_s {
    uint8_t arg_idx;
    uint16_t content_off; // offset into content
    uint16_t content_sz; // size not including
    uint8_t sizes[9];
    uint8_t *content;
} *os_trace_buffer_context_t;

static bool
_os_trace_encode_scalar(const void *arg, uint16_t arg_len, os_trace_buffer_context_t context)
{
    if (context->arg_idx > 7) {
        return false;
    }

    uint8_t *content = &context->content[context->content_off];
    if ((context->content_off + arg_len) > context->content_sz) {
        return false;
    }

    memcpy(content, arg, arg_len);
    context->sizes[context->arg_idx++] = arg_len;
    context->content_off += arg_len;

    context->arg_idx++;

    return true;
}

static inline bool
_os_trace_skip_arg(os_trace_buffer_context_t context)
{
    return _os_trace_encode_scalar(NULL, 0, context);
}

static bool
_os_trace_encode(const char *format, va_list args, int saved_errno, os_trace_buffer_context_t context)
{
	const char *percent = strchr(format, '%');

	while (percent != NULL) {
		++percent;
		if (percent[0] != '%') {
			struct os_trace_format_value_s value;
			int		type = T_INT;
			bool	long_double = false;
			int		prec = 0;
			char	ch;

			for (bool done = false; !done; percent++) {
				switch (ch = percent[0]) {
						/* type of types or other */
					case 'l': // longer
						type++;
						break;

					case 'h': // shorter
						type--;
						break;

					case 'z':
						type = T_SIZE;
						break;

					case 'j':
						type = T_INTMAX;
						break;

					case 't':
						type = T_PTRDIFF;
						break;

					case '.': // precision
						if ((percent[1]) == '*') {
							prec = va_arg(args, int);
							_os_trace_encode_scalar(&prec, sizeof(prec), context);
							percent++;
							continue;
						}
						break;

					case '-': // left-align
					case '+': // force sign
					case ' ': // prefix non-negative with space
					case '#': // alternate
					case '\'': // group by thousands
						break;

					case '{': // annotated symbols
						for (const char *curr2 = percent + 1; (ch = (*curr2)) != 0; curr2++) {
							if (ch == '}') {
								percent = curr2;
								break;
							}
						}
						break;

						/* fixed types */
					case 'd': // integer
					case 'i': // integer
					case 'o': // octal
					case 'u': // unsigned
					case 'x': // hex
					case 'X': // upper-hex
						switch (type) {
							case T_CHAR:
								value.type.ch = va_arg(args, int);
								_os_trace_encode_scalar(&value.type.ch, sizeof(value.type.ch), context);
								break;

							case T_SHORT:
								value.type.s = va_arg(args, int);
								_os_trace_encode_scalar(&value.type.s, sizeof(value.type.s), context);
								break;

							case T_INT:
								value.type.i = va_arg(args, int);
								_os_trace_encode_scalar(&value.type.i, sizeof(value.type.i), context);
								break;

							case T_LONG:
								value.type.l = va_arg(args, long);
								_os_trace_encode_scalar(&value.type.l, sizeof(value.type.l), context);
								break;

							case T_LONGLONG:
								value.type.ll = va_arg(args, long long);
								_os_trace_encode_scalar(&value.type.ll, sizeof(value.type.ll), context);
								break;

							case T_SIZE:
								value.type.z = va_arg(args, size_t);
								_os_trace_encode_scalar(&value.type.z, sizeof(value.type.z), context);
								break;

							case T_INTMAX:
								value.type.im = va_arg(args, intmax_t);
								_os_trace_encode_scalar(&value.type.im, sizeof(value.type.im), context);
								break;

							case T_PTRDIFF:
								value.type.pd = va_arg(args, ptrdiff_t);
								_os_trace_encode_scalar(&value.type.pd, sizeof(value.type.pd), context);
								break;

							default:
								return false;
						}
						done = true;
						break;

					case 'P': // pointer data
                        _os_trace_skip_arg(context);
						break;

					case 'L': // long double
						long_double = true;
						break;

					case 'a': case 'A': case 'e': case 'E': // floating types
					case 'f': case 'F': case 'g': case 'G':
						if (long_double) {
							value.type.ld = va_arg(args, long double);
							_os_trace_encode_scalar(&value.type.ld, sizeof(value.type.ld), context);
						} else {
							value.type.d = va_arg(args, double);
							_os_trace_encode_scalar(&value.type.d, sizeof(value.type.d), context);
						}
						done = true;
						break;

					case 'c': // char
						value.type.ch = va_arg(args, int);
						_os_trace_encode_scalar(&value.type.ch, sizeof(value.type.ch), context);
						done = true;
						break;

					case 'C': // wide-char
						value.type.wch = va_arg(args, wint_t);
						_os_trace_encode_scalar(&value.type.wch, sizeof(value.type.wch), context);
						done = true;
						break;

					case '@':
                        _os_trace_skip_arg(context);
						break;

					case 'm':
						value.type.i = saved_errno;
						_os_trace_encode_scalar(&value.type.i, sizeof(value.type.i), context);
						done = true;
						break;

					default:
						if (isdigit(ch)) { // [0-9]
							continue;
						}
						return false;
				}

				if (done) {
					percent = strchr(percent, '%'); // Find next format
					break;
				}
			}
		} else {
			percent = strchr(percent+1, '%'); // Find next format after %%
		}
	}

	context->content_sz = context->content_off;
	context->arg_idx = context->content_off = 0;

	return true;
}

#define OS_TRACE_BUFFER_MAX_SIZE 1024

__attribute__((swiftcall, __visibility__("default")))
void _loggy_swift_os_trace(void *dso, uint8_t type, const char *format, va_list args)
{
    struct os_trace_buffer_context_s context2 = { };
    uint8_t *content2 = alloca(OS_TRACE_BUFFER_MAX_SIZE);
    int save_errno2 = errno; // %m

    memset(content2, 0, OS_TRACE_BUFFER_MAX_SIZE);

    context2.content = content2;
    context2.content_sz = OS_TRACE_BUFFER_MAX_SIZE - (sizeof(uint8_t) * 9);

    if (_os_trace_encode(format, args, save_errno2, &context2)) {
        uint16_t content_sz = context2.content_sz;
        uint8_t nsizes = context2.arg_idx;

        context2.sizes[nsizes] = nsizes;
        memcpy(content2 + nsizes, context2.sizes, sizeof(uint8_t) * nsizes);
        content_sz += sizeof(uint8_t) * nsizes;

        _os_trace_with_buffer(dso, format, type, content2, content_sz, NULL);
    }
}

__attribute__((swiftcall, __visibility__("default")))
uint8_t
_loggy_swift_os_trace_type_error(void) {
    return OS_TRACE_TYPE_ERROR;
}

__attribute__((swiftcall, __visibility__("default")))
uint8_t
_loggy_swift_os_trace_type_fault(void) {
    return OS_TRACE_TYPE_FAULT;
}
