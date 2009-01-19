/*
  Copyright 2003-2008 Andrew Ross
 
  This file is part of Nasal.
 
  Nasal is free software; you can redistribute it and/or
  modify it under the terms of the GNU Library General Public
  License as published by the Free Software Foundation; either
  version 2 of the License, or (at your option) any later version.

  Nasal is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Library General Public License for more details.

  You should have received a copy of the GNU Library General Public
  License along with Nasal; if not, write to the Free
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/

#ifndef _IOLIB_H
#define _IOLIB_H

#include "nasal.h"

// Note use of 32 bit ints, should fix at some point to use
// platform-dependent fpos_t/size_t or just punt and use int64_t
// everywhere...

// The naContext is passed in for error reporting via
// naRuntimeError().
struct naIOType {
    void (*close)(naContext c, void* f);
    int  (*read) (naContext c, void* f, char* buf, unsigned int len);
    int  (*write)(naContext c, void* f, char* buf, unsigned int len);
    void (*seek) (naContext c, void* f, unsigned int off, int whence);
    int  (*tell) (naContext c, void* f);
    void (*destroy)(void* f);
};

struct naIOGhost {
    struct naIOType* type;
    void* handle; // descriptor, FILE*, HANDLE, etc...
};

extern naGhostType naIOGhostType;
extern struct naIOType naStdIOType;

#define IOGHOST(r) ((struct naIOGhost*)naGhost_ptr(r))
#define IS_IO(r) (IS_GHOST(r) && naGhost_type(r) == &naIOGhostType)
#define IS_STDIO(r) (IS_IO(r) && (IOGHOST(r)->type == &naStdIOType))

// Defined in iolib.c, there is no "library" header to put this in
naRef naIOGhost(naContext c, FILE* f);

#endif // _IOLIB_H
