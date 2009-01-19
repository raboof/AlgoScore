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

#include <pcre.h>
#include <string.h>
#include "data.h"

static void regexDestroy(void* r);
static const naGhostType naRegexGhostType = { regexDestroy, "regex" };

struct Regex {
    pcre* re;
    pcre_extra* extra;
};

static int parseOpts(naContext c, char* s)
{
    int opts = 0;
    while(*s) {
        switch(*s++) {
        case 'i': opts |= PCRE_CASELESS; break;
        case 'm': opts |= PCRE_MULTILINE; break;
        case 's': opts |= PCRE_DOTALL; break;
        case 'x': opts |= PCRE_EXTENDED; break;
        default: naRuntimeError(c, "unrecognized regex option");
        }
    }
    return opts;
}

static naRef f_comp(naContext c, naRef me, int argc, naRef* args)
{
    int erroff, opts = 0;
    const char* errptr;
    struct Regex* regex;
    naRef pat = argc > 0 ? naStringValue(c, args[0]) : naNil();
    naRef optr = argc > 1 ? args[1] : naNil();
    if(!IS_STR(pat) || (!IS_NIL(optr) && !IS_STR(optr)))
        naRuntimeError(c, "bad arg to regex.comp");
    if(IS_STR(optr)) opts = parseOpts(c, naStr_data(optr));
    regex = naAlloc(sizeof(struct Regex));
    regex->re = pcre_compile(naStr_data(pat), opts, &errptr, &erroff, 0);
    if(regex->re == 0) {
        naFree(regex);
        naRuntimeError(c, "bad regex"); // FIXME: expose errptr/erroff
    }
    regex->extra = pcre_study(regex->re, 0, &errptr);
    return naNewGhost(c, (void*)&naRegexGhostType, regex);
}

static naRef f_exec(naContext c, naRef me, int argc, naRef* args)
{
    int i, n, i0, ovector[30];
    struct Regex* r = argc > 0 ? naGhost_ptr(args[0]) : 0;
    naRef result, str = argc > 1 ? naStringValue(c, args[1]) : naNil();
    naRef start = argc > 2 ? naNumValue(args[2]) : naNum(0);
    if(!r || naGhost_type(args[0]) != &naRegexGhostType || !IS_NUM(start))
        naRuntimeError(c, "bad argument to regex.study");
    i0 = (int)start.num;
    n = pcre_exec(r->re, r->extra, naStr_data(str)+i0,
                  naStr_len(str)-i0, 0, 0, ovector, 30);
    result = naNewVector(c);
    if(n > 0) {
        naVec_setsize(result, n*2);
        for(i=0; i<2*n; i++) naVec_set(result, i, naNum(ovector[i]+i0));
    }
    return result;
}

static void regexDestroy(void* r)
{
    struct Regex* regex = (struct Regex*)r;
    pcre_free(regex->re);
    if(regex->extra) pcre_free(regex->extra);
    naFree(regex);
}

static naCFuncItem funcs[] = {
    { "comp", f_comp },
    { "exec", f_exec },
    { 0 }
};

naRef naInit_regex(naContext c)
{
    return naGenLib(c, funcs);
}
