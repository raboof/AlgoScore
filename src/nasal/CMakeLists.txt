if (HAVE_PCRE)
    set (pcre regexlib.c)
endif ()

set (SOURCES
    bitslib.c code.c codegen.c debug.c gc.c hash.c
    iolib.c lex.c lib.c mathlib.c misc.c parse.c
    string.c thread-posix.c thread-win32.c threadlib.c unixlib.c
    utf8lib.c vector.c code.h data.h iolib.h nasal.h
    parse.h gtklib.c cairolib.c ${pcre}
)

add_library (nasal ${SOURCES})
