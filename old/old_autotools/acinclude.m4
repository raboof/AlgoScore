dnl Function to check for Mac OS X frameworks (stolen from Basilisk)
dnl AC_CHECK_FRAMEWORK($1=NAME, $2=INCLUDES, $3=ACTION-IF-FOUND)
AC_DEFUN([AC_CHECK_FRAMEWORK], [
  AS_VAR_PUSHDEF([ac_Framework], [have_framework_$1])dnl
  AC_CACHE_CHECK([whether compiler supports framework $1],
    ac_Framework, [
    saved_LIBS="$LIBS"
    LIBS="$LIBS -framework $1"
    AC_TRY_LINK(
      [$2], [],
      [AS_VAR_SET(ac_Framework, yes); LDFLAGS="$LDFLAGS -Wl,-framework,$1"], [AS_VAR_SET(ac_Framework, no); LIBS="$saved_LIBS"]
    )
  ])
  AS_IF([test AS_VAR_GET(ac_Framework) = yes],
    [$3]
  )
  AS_VAR_POPDEF([ac_Framework])dnl
])

#    [AC_DEFINE(AS_TR_CPP(HAVE_FRAMEWORK_$1), 1, [Define if framework $1 is available.])]
