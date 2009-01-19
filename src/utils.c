/*
  Copyright 2007, 2008, Jonatan Liljedahl

  This file is part of AlgoScore.

  AlgoScore is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  AlgoScore is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with AlgoScore.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <glib.h>
#include "nasal.h"

/*static naRef *saved;

void naSave2(

void utils_init(void) {
    saved = na..
    gah.. need a nasal context also. why?
}
*/

gchar *get_stack_trace(naContext ctx)
{
    int i;
    char *buf = g_strdup_printf("%s\n  at %s, line %d\n", naGetError(ctx),
        naStr_data(naGetSourceFile(ctx, 0)), naGetLine(ctx, 0));
    
    for(i=1; i<naStackDepth(ctx); i++) {
        char *o = buf;
        char *s = g_strdup_printf("  called from: %s, line %d\n",
            naStr_data(naGetSourceFile(ctx, i)), naGetLine(ctx, i));
        buf = g_strconcat(buf,s,NULL);
        g_free(o);
        g_free(s);
    }
    return buf;
}

#define ERR_STR "Arg %d to %s() not a "

naRef check_arg(naContext ctx, int n, int ac, naRef *av, const char* fn)
{
    if(n >= ac) naRuntimeError(ctx, "Not enough arguments to %s()", fn);
    return av[n];
}

naRef arg_str(naContext c, int argc, naRef *a, int n, const char *f)
{
    naRef r = naStringValue(c,check_arg(c,n,argc,a,f));
    if(!naIsString(r)) naRuntimeError(c,ERR_STR "string",n+1,f);
    return r;
}

double arg_num(naContext c, int argc, naRef *a, int n, const char *f)
{
    naRef r = naNumValue(check_arg(c,n,argc,a,f));
    if(!naIsNum(r)) naRuntimeError(c,ERR_STR "number",n+1,f);
    return r.num;
}

naRef arg_func(naContext c, int argc, naRef *a, int n, const char* f)
{
    naRef r = check_arg(c,n,argc,a,f);
    if(!naIsFunc(r))
        naRuntimeError(c,ERR_STR "function", n+1, f);
    return r;
}

naRef arg_vec(naContext c, int argc, naRef *a, int n, const char* f)
{
    naRef r = check_arg(c,n,argc,a,f);
    if(!naIsVector(r))
        naRuntimeError(c,ERR_STR "vector", n+1, f);
    return r;
}
