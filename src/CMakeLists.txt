cmake_minimum_required(VERSION 2.4)

project (ALGOSCORE)

include (CheckLibraryExists)
include (FindPkgConfig)

set (CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS true)
set (EXECUTABLE_OUTPUT_PATH ${ALGOSCORE_SOURCE_DIR}/..)
set (CMAKE_COLOR_MAKEFILE ON)

add_definitions( -O2 )

if (APPLE)
    set (CMAKE_OSX_ARCHITECTURES ppc;i386 )
    add_definitions( -I/usr/local/include ) # this shouldn't be needed
    #set (CMAKE_EXE_LINKER_FLAGS "-undefined dynamic_lookup")

    set (MAC_INTEGRATION TRUE)
    set (MAC_INTEGRATION_SRC ige-mac-menu.c)
    find_library (CARBON Carbon)
    find_library (APPSERV ApplicationServices)
    find_library (APPKIT AppKit)
    set (MAC_INTEGRATION_LIBS ${CARBON} ${APPKIT} ${APPSERV} objc)
    add_definitions( -xobjective-c )
endif ()

#check_library_exists (pcre pcre_compile "" HAVE_PCRE)
message (STATUS "checking for PCRE")
find_path (PCRE_INCLUDE_DIR
    NAMES pcre.h
    PATHS /usr/local/include /usr/include
)
find_library (PCRE_LIBRARY
    NAMES pcre
    PATHS /usr/local/lib /usr/lib
)
if (PCRE_LIBRARY AND PCRE_INCLUDE_DIR)
    set (HAVE_PCRE TRUE)
    message (STATUS "  library: ${PCRE_LIBRARY}")
    message (STATUS "  headers: ${PCRE_INCLUDE_DIR}")
else ()
    message (STATUS "  not found.")
    set (PCRE_LIBRARY "")
    set (PCRE_INCLUDE_DIR "")
endif ()

find_package (Threads REQUIRED)
find_library (DL_LIBRARY dl /usr/local/include /usr/include)
find_library (SNDFILE_LIBRARY sndfile /usr/local/include /usr/include)

message (STATUS "checking for Csound")
find_path (CSOUND_INCLUDE_DIR
    NAMES csound/csound.h CsoundLib/csound.h
    PATHS /usr/local/include /usr/include
)
find_library (CSOUND_LIBRARY
    NAMES csound64 csound CsoundLib
    PATHS /usr/local/lib /usr/lib
)
if (CSOUND_LIBRARY AND CSOUND_INCLUDE_DIR)
    set (HAVE_CSOUND TRUE)
    message (STATUS "  library: ${CSOUND_LIBRARY}")
    message (STATUS "  headers: ${CSOUND_INCLUDE_DIR}")
    if (CSOUND_LIBRARY MATCHES "CsoundLib.framework")
        message (STATUS "  using framework")
        set (CSOUND_FRAMEWORK TRUE)
        set (CSOUND_LIBRARIES ${CSOUND_LIBRARY})
    else ()
        set (CSOUND_LIBRARIES
            ${DL_LIBRARY}
            ${CSOUND_LIBRARY}
        )
    endif ()
    if (CSOUND_LIBRARY MATCHES "csound64")
        message (STATUS "  using double precision")
        set (USE_DOUBLE TRUE)
    endif ()
else ()
    message (STATUS "  not found. CSOUND SUPPORT DISABLED!")
endif ()

pkg_check_modules (GTK REQUIRED gtk+-2.0>=2.8 gthread-2.0>=2.10)

pkg_check_modules (SNDFILE sndfile>=1.0)

pkg_check_modules (JACK REQUIRED jack>=0.100)
set (midi_msg "checking jack midi API:")
if (JACK_VERSION STRLESS 0.102.27)
    set (JACK_NO_MIDI TRUE)
    message (STATUS "${midi_msg} not supported")
elseif (JACK_VERSION STRLESS 0.105.0)
    set (JACK_OLD_MIDI TRUE)
    message (STATUS "${midi_msg} old but working")
else ()
    set (JACK_STABLE_MIDI TRUE)
    message (STATUS "${midi_msg} stable")
endif ()

pkg_check_modules (LIBLO liblo>=0.24)

if (LIBLO_FOUND)
    message (STATUS "OSC support enabled")
else ()
    message (STATUS "OSC support disabled!")
endif ()

include_directories (
    ${ALGOSCORE_SOURCE_DIR}/nasal
    ${GTK_INCLUDE_DIRS}
    ${CSOUND_INCLUDE_DIR}
    ${ALGOSCORE_BINARY_DIR}
    ${PCRE_INCLUDE_DIR}
    ${SNDFILE_INCLUDE_DIRS}
    ${JACK_INCLUDE_DIRS}
)

link_directories (
    ${ALGOSCORE_BINARY_DIR}/nasal
    ${GTK_LIBRARY_DIRS}
    ${JACK_LIBRARY_DIRS}
)

configure_file (
    ${ALGOSCORE_SOURCE_DIR}/config.h.cmake
    ${ALGOSCORE_BINARY_DIR}/config.h
)

add_subdirectory (nasal)

if (HAVE_CSOUND)
    set (csound csoundlib.c)
endif ()

set (SOURCES
    algoscore.c
    playbuslib.c
    utils.c utils.h
    mathxlib.c
    sflib.c
    ${csound}
    ${MAC_INTEGRATION_SRC}
)

add_executable (algoscore ${SOURCES})
target_link_libraries (algoscore
    nasal
    ${CMAKE_THREAD_LIBS_INIT}
    ${GTK_LIBRARIES}
    ${SNDFILE_LIBRARIES}
    ${CSOUND_LIBRARIES}
    ${JACK_LIBRARIES}
    ${PCRE_LIBRARY}
    ${LIBLO_LIBRARIES}
    ${MAC_INTEGRATION_LIBS}
)
