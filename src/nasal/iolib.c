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

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "data.h"
#include "iolib.h"

static void ghostDestroy(void* g);
naGhostType naIOGhostType = { ghostDestroy, "iofile" };

static struct naIOGhost* ioghost(naRef r)
{
    if(naGhost_type(r) == &naIOGhostType && IOGHOST(r)->handle)
        return naGhost_ptr(r);
    return 0;
}

static naRef f_close(naContext c, naRef me, int argc, naRef* args)
{
    struct naIOGhost* g = argc==1 ? ioghost(args[0]) : 0;
    if(!g) naRuntimeError(c, "bad argument to close()");
    if(g->handle) g->type->close(c, g->handle);
    g->handle = 0;
    return naNil();
}

static naRef f_read(naContext c, naRef me, int argc, naRef* args)
{
    struct naIOGhost* g = argc > 0 ? ioghost(args[0]) : 0;
    naRef str = argc > 1 ? args[1] : naNil();
    naRef len = argc > 2 ? naNumValue(args[2]) : naNil();
    if(!g || !MUTABLE(str) || !IS_NUM(len))
        naRuntimeError(c, "bad argument to read()");
    if(naStr_len(str) < (int)len.num)
        naRuntimeError(c, "string not big enough for read");
    return naNum(g->type->read(c, g->handle, naStr_data(str),
                               (int)len.num));
}

static naRef f_write(naContext c, naRef me, int argc, naRef* args)
{
    struct naIOGhost* g = argc > 0 ? ioghost(args[0]) : 0;
    naRef str = argc > 1 ? args[1] : naNil();
    if(!g || !IS_STR(str))
        naRuntimeError(c, "bad argument to write()");
    return naNum(g->type->write(c, g->handle, naStr_data(str),
                                naStr_len(str)));
}

static naRef f_seek(naContext c, naRef me, int argc, naRef* args)
{
    struct naIOGhost* g = argc > 0 ? ioghost(args[0]) : 0;
    naRef pos = argc > 1 ? naNumValue(args[1]) : naNil();
    naRef whn = argc > 2 ? naNumValue(args[2]) : naNil();
    if(!g || !IS_NUM(pos) || !IS_NUM(whn))
        naRuntimeError(c, "bad argument to seek()");
    g->type->seek(c, g->handle, (int)pos.num, (int)whn.num);
    return naNil();
}

static naRef f_tell(naContext c, naRef me, int argc, naRef* args)
{
    struct naIOGhost* g = argc==1 ? ioghost(args[0]) : 0;
    if(!g)
        naRuntimeError(c, "bad argument to tell()");
    return naNum(g->type->tell(c, g->handle));
}

static void ghostDestroy(void* g)
{
    struct naIOGhost* io = (struct naIOGhost*)g;
    io->type->destroy(io->handle);
    naFree(io);
}

////////////////////////////////////////////////////////////////////////
// stdio library implementation below:

static void ioclose(naContext c, void* f)
{
    if(f)
        if(fclose(f) != 0 && c) naRuntimeError(c, strerror(errno));
}

static int ioread(naContext c, void* f, char* buf, unsigned int len)
{
    int n;
    naModUnlock(); n = fread(buf, 1, len, f); naModLock();
    if(n < len && !feof((FILE*)f)) naRuntimeError(c, strerror(errno));
    return n;
}

static int iowrite(naContext c, void* f, char* buf, unsigned int len)
{
    int n;
    naModUnlock(); n = fwrite(buf, 1, len, f); naModLock();
    if(ferror((FILE*)f)) naRuntimeError(c, strerror(errno));
    return n;
}

static void ioseek(naContext c, void* f, unsigned int off, int whence)
{
    if(fseek(f, off, whence) != 0) naRuntimeError(c, strerror(errno));
}

static int iotell(naContext c, void* f)
{
    int n = ftell(f);
    if(n < 0) naRuntimeError(c, strerror(errno));
    return n;
}

static void iodestroy(void* f)
{
    if(f != stdin && f != stdout && f != stderr)
        ioclose(0, f);
}

struct naIOType naStdIOType = { ioclose, ioread, iowrite, ioseek,
                                iotell, iodestroy };

naRef naIOGhost(naContext c, FILE* f)
{
    struct naIOGhost* ghost = naAlloc(sizeof(struct naIOGhost));
    ghost->type = &naStdIOType;
    ghost->handle = f;
    return naNewGhost(c, &naIOGhostType, ghost);
}

static naRef f_open(naContext c, naRef me, int argc, naRef* args)
{
    FILE* f;
    naRef file = argc > 0 ? naStringValue(c, args[0]) : naNil();
    naRef mode = argc > 1 ? naStringValue(c, args[1]) : naNil();
    if(!IS_STR(file)) naRuntimeError(c, "bad argument to open()");
    f = fopen(naStr_data(file), IS_STR(mode) ? naStr_data(mode) : "rb");
    if(!f) naRuntimeError(c, strerror(errno));
    return naIOGhost(c, f);
}

// frees buffer before tossing an error
static int getcguard(naContext ctx, FILE* f, void* buf)
{
    int c;
    naModUnlock(); c = fgetc(f); naModLock();
    if(ferror(f)) {
        naFree(buf);
        naRuntimeError(ctx, strerror(errno));
    }
    return c;
}

// Handles multiple EOL conventions by using stdio's ungetc.  Will not
// work for other IO types without converting them to FILE* with
// fdopen() or whatnot...
static naRef f_readln(naContext ctx, naRef me, int argc, naRef* args)
{
    naRef result;
    struct naIOGhost* g = argc==1 ? ioghost(args[0]) : 0;
    int i=0, c, sz = 128;
    char *buf;
    if(!g || g->type != &naStdIOType)
        naRuntimeError(ctx, "bad argument to readln()");
    buf = naAlloc(sz);
    while(1) {
        c = getcguard(ctx, g->handle, buf);
        if(c == EOF || c == '\n') break;
        if(c == '\r') {
            int c2 = getcguard(ctx, g->handle, buf);
            if(c2 != EOF && c2 != '\n')
                if(EOF == ungetc(c2, g->handle))
                    break;
            break;
        }
        buf[i++] = c;
        if(i >= sz) buf = naRealloc(buf, sz *= 2);
    }
    result = c == EOF ? naNil() : naStr_fromdata(naNewString(ctx), buf, i);
    naFree(buf);
    return result;
}

static naRef f_stat(naContext ctx, naRef me, int argc, naRef* args)
{
    int n=0;
    struct stat s;
    naRef result, path = argc > 0 ? naStringValue(ctx, args[0]) : naNil();
    if(!IS_STR(path)) naRuntimeError(ctx, "bad argument to stat()");
    if(stat(naStr_data(path), &s) < 0) {
        if(errno == ENOENT) return naNil();
        naRuntimeError(ctx, strerror(errno));
    }
    result = naNewVector(ctx);
    naVec_setsize(result, 11);
#define FLD(x) naVec_set(result, n++, naNum(s.st_##x));
    FLD(dev);  FLD(ino);  FLD(mode);  FLD(nlink);  FLD(uid);  FLD(gid);
    FLD(rdev); FLD(size); FLD(atime); FLD(mtime);  FLD(ctime);
#undef FLD
    return result;
}

static naRef _mode_to_str(naContext ctx, struct stat *st) {
    mode_t m = st->st_mode;
    char *s = "unknown";
#define CHK(x,y) if(S_IS##x(m)) s = #y
    CHK(DIR,dir);    else
    CHK(REG,file);   else
    CHK(CHR,chrdev); else
    CHK(BLK,blkdev); else
    CHK(FIFO,fifo);  else
    CHK(LNK,link);   else
    CHK(SOCK,socket);
#undef CHK
    return naStr_fromdata(naNewString(ctx), (s), strlen((s)));
}

static naRef f_filetype(naContext ctx, naRef me, int argc, naRef* args)
{
    struct stat s;
    naRef f = argc > 0 ? args[0] : naNil();
    struct naIOGhost* g = ioghost(f);
    if(g) {
        if(fstat(fileno(g->handle),&s) < 0) {
            if(errno == ENOENT) return naNil();
            naRuntimeError(ctx, strerror(errno));
        }
        return _mode_to_str(ctx, &s);
    }
    f = naStringValue(ctx, f);
    if(IS_STR(f)) {
        if(stat(naStr_data(f), &s) < 0) {
            if(errno == ENOENT) return naNil();
            naRuntimeError(ctx, strerror(errno));
        }
        return _mode_to_str(ctx, &s);
    } else
        naRuntimeError(ctx, "bad argument to filetype()");
}

static naCFuncItem funcs[] = {
    { "close", f_close },
    { "read", f_read },
    { "write", f_write },
    { "seek", f_seek },
    { "tell", f_tell },
    { "open", f_open },
    { "readln", f_readln },
    { "stat", f_stat },
    { "filetype", f_filetype },
    { 0 }
};

naRef naInit_io(naContext c)
{
    naRef ns = naGenLib(c, funcs);
    naAddSym(c, ns, "SEEK_SET", naNum(SEEK_SET));
    naAddSym(c, ns, "SEEK_CUR", naNum(SEEK_CUR));
    naAddSym(c, ns, "SEEK_END", naNum(SEEK_END));
    naAddSym(c, ns, "stdin", naIOGhost(c, stdin));
    naAddSym(c, ns, "stdout", naIOGhost(c, stdout));
    naAddSym(c, ns, "stderr", naIOGhost(c, stderr));
    return ns;
}
