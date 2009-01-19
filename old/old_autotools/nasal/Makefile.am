noinst_LTLIBRARIES = libnasal.la

if HAVE_PCRE
pcre = regexlib.c
endif

#if HAVE_SQLITE
#sqlite = sqlitelib.c
#endif

libnasal_la_SOURCES = bitslib.c code.c codegen.c debug.c gc.c hash.c    \
                      iolib.c lex.c lib.c mathlib.c misc.c parse.c      \
                      string.c thread-posix.c thread-win32.c threadlib.c unixlib.c  \
                      utf8lib.c vector.c code.h	data.h iolib.h nasal.h  \
                      parse.h gtklib.c cairolib.c $(pcre) $(sqlite)


libnasal_la_LDFLAGS = -version-info @LIBTOOL_VERSION_INFO@
