#include "nasal.h"

static naRef f_zoo(naContext ctx, naRef me, int argc, naRef *args)
{
    return naNum(123);
}

static naCFuncItem funcs[] = {
    { "zoo", f_zoo },
    { 0 }
};


naRef init_nasal_namespace(naContext ctx) {
    naRef ns = naGenLib(ctx, funcs);
    naAddSym(ctx, ns, "bar", naNum(42));
    return ns;
}

