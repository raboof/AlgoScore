noinst_PROGRAMS = algoscore

SUBDIRS = nasal
AM_CFLAGS = -O2

if HAVE_CSOUND
csound = csoundlib.c
endif

algoscore_SOURCES = algoscore.c playbuslib.c \
    utils.c utils.h mathxlib.c $(csound)

algoscore_LDADD = nasal/libnasal.la

#INCLUDES = -I../nasal
INCLUDES = -I$(top_srcdir)/nasal

tarball: distclean
	./make_release
