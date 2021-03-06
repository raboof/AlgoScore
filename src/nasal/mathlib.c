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

#include <math.h>
#include <string.h>

#include "nasal.h"

// Toss a runtime error for any NaN or Inf values produced.  Note that
// this assumes an IEEE 754 format.
#define VALIDATE(r) (valid(r.num) ? (r) : die(c, __FUNCTION__+2))

static int valid(double d)
{
    union { double d; unsigned long long ull; } u;
    u.d = d;
    return ((u.ull >> 52) & 0x7ff) != 0x7ff;
}

static naRef die(naContext c, const char* fn)
{
    naRuntimeError(c, "floating point error in math.%s()", fn);
    return naNil();
}

static naRef f_sin(naContext c, naRef me, int argc, naRef* args)
{
    naRef a = naNumValue(argc > 0 ? args[0] : naNil());
    if(naIsNil(a))
        naRuntimeError(c, "non numeric argument to sin()");
    a.num = sin(a.num);
    return VALIDATE(a);
}

static naRef f_cos(naContext c, naRef me, int argc, naRef* args)
{
    naRef a = naNumValue(argc > 0 ? args[0] : naNil());
    if(naIsNil(a))
        naRuntimeError(c, "non numeric argument to cos()");
    a.num = cos(a.num);
    return VALIDATE(a);
}

static naRef f_exp(naContext c, naRef me, int argc, naRef* args)
{
    naRef a = naNumValue(argc > 0 ? args[0] : naNil());
    if(naIsNil(a))
        naRuntimeError(c, "non numeric argument to exp()");
    a.num = exp(a.num);
    return VALIDATE(a);
}

static naRef f_ln(naContext c, naRef me, int argc, naRef* args)
{
    naRef a = naNumValue(argc > 0 ? args[0] : naNil());
    if(naIsNil(a))
        naRuntimeError(c, "non numeric argument to ln()");
    a.num = log(a.num);
    return VALIDATE(a);
}

static naRef f_sqrt(naContext c, naRef me, int argc, naRef* args)
{
    naRef a = naNumValue(argc > 0 ? args[0] : naNil());
    if(naIsNil(a))
        naRuntimeError(c, "non numeric argument to sqrt()");
    a.num = sqrt(a.num);
    return VALIDATE(a);
}

static naRef f_atan2(naContext c, naRef me, int argc, naRef* args)
{
    naRef a = naNumValue(argc > 0 ? args[0] : naNil());
    naRef b = naNumValue(argc > 1 ? args[1] : naNil());
    if(naIsNil(a) || naIsNil(b))
        naRuntimeError(c, "non numeric argument to atan2()");
    a.num = atan2(a.num, b.num);
    return VALIDATE(a);
}

static naCFuncItem funcs[] = {
    { "sin", f_sin },
    { "cos", f_cos },
    { "exp", f_exp },
    { "ln", f_ln },
    { "sqrt", f_sqrt },
    { "atan2", f_atan2 },
    { 0 }
};

naRef naInit_math(naContext c)
{
    naRef ns = naGenLib(c, funcs);
    naAddSym(c, ns, "pi", naNum(3.14159265358979323846));
    naAddSym(c, ns, "e", naNum(2.7182818284590452354));
    return ns;
}
