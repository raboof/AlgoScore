#ifndef _GTKLIB_H_
#define _GTKLIB_H_

void* gobjarg(naContext ctx, int n, int ac, naRef *av, const char* fn);

#define OBJARG(n) gobjarg(ctx, (n), argc, args, (__FUNCTION__+2))

#endif
