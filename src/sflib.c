/*
  Copyright 2008, Jonatan Liljedahl

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

#include <stdlib.h>
#include <string.h>
#include <sndfile.h>

#include "nasal.h"
#include "utils.h"

#define NASTR(b) naStr_fromdata(naNewString(ctx), (char*)(b), strlen(b))

typedef struct { SNDFILE *sf; } sfGhost;
static void sfGhostDestroy(sfGhost *g)
{
    if(g->sf) sf_close(g->sf);
    free(g);
}
static naGhostType sfGhostType = {
    (void(*)(void*))sfGhostDestroy, "SoundFile"
};
naRef newSfGhost(naContext ctx, SNDFILE *sf)
{
    sfGhost *g = malloc(sizeof(sfGhost));
    g->sf = sf;
    return naNewGhost(ctx,&sfGhostType,g);
}
static SNDFILE *ghost2sf(naRef r)
{
    if(naGhost_type(r) != &sfGhostType)
        return 0;
    return ((sfGhost*)naGhost_ptr(r))->sf;
}

static SNDFILE *arg_sf(naContext c, int argc, naRef *a, int n, const char *f)
{
    SNDFILE *fp = ghost2sf(check_arg(c,n,argc,a,f));
    if(!fp) naRuntimeError(c,"Arg %d to %s() not a SoundFile",n+1,f);
    return fp;
}

#define SFARG(n) arg_sf(ctx, argc, args, (n), (__FUNCTION__+2))

static naRef f_open(naContext ctx, naRef me, int argc, naRef *args)
{
    SF_INFO info;
    SNDFILE *sf;
    char *fn = naStr_data(STRARG(0));
    int mode = NUMARG(1);
    info.format = NUMARG(2);
    info.channels = NUMARG(3);
    info.samplerate = NUMARG(4);

    if((sf = sf_open(fn,mode,&info))==0) {
        naRuntimeError(ctx,"Could not open soundfile %s for writing: %s\n",fn,sf_strerror(sf));
    }
    return newSfGhost(ctx,sf);
}

static naRef f_write(naContext ctx, naRef me, int argc, naRef *args)
{
    SNDFILE *sf = SFARG(0);
//    float val = NUMARG(1);
    naRef v = VECARG(1);
    int sz = naVec_size(v);
    float buf[sz];
    int i;
    
    for(i=0;i<sz;i++)
        buf[i]=naNumValue(naVec_get(v,i)).num;

    sf_writef_float(sf,buf,sz);
//    sf_writef_float(sf,&val,1); //FIXME, handle multichannel and more than one frame
    return naNil();
}

static naRef f_close(naContext ctx, naRef me, int argc, naRef *args)
{
    SNDFILE *sf = SFARG(0);
    sf_close(sf);
    ((sfGhost*)naGhost_ptr(args[0]))->sf = 0;
    return naNil();
}

/* based on code from libsndfile (examples/list_formats.c) by Erik de Castro Lopo */
static naRef f_list_formats(naContext ctx, naRef me, int argc, naRef *args)
{
    SF_FORMAT_INFO info;
    SF_INFO sfinfo;
    int format, major_count, subtype_count, m, s;
    naRef list = naNewHash(ctx);

    memset(&sfinfo, 0, sizeof(sfinfo));

    sf_command(NULL, SFC_GET_FORMAT_MAJOR_COUNT, &major_count, sizeof(int));
    sf_command(NULL, SFC_GET_FORMAT_SUBTYPE_COUNT, &subtype_count, sizeof(int));

    sfinfo.channels = 1;
    for(m = 0; m < major_count; m++) {
        naRef v = naNewVector(ctx);
        naRef sublist = naNewHash(ctx);
        info.format = m;
	sf_command(NULL, SFC_GET_FORMAT_MAJOR, &info, sizeof(info));
        naHash_set(list,naNum(info.format),v);
        naVec_append(v,NASTR(info.name));
        naVec_append(v,NASTR(info.extension));
        naVec_append(v,sublist);

	format = info.format;

	for(s = 0; s < subtype_count; s++) {
            info.format = s;
	    sf_command(NULL, SFC_GET_FORMAT_SUBTYPE, &info, sizeof(info));
	    format = (format & SF_FORMAT_TYPEMASK) | info.format;

	    sfinfo.format = format;
	    if(sf_format_check(&sfinfo))
                naHash_set(sublist,naNum(info.format),NASTR(info.name));
	}
    }

    return list;
}

#define F(x) { #x, f_##x }
static naCFuncItem funcs[] = {
    F(list_formats),
    F(open),
    F(close),
    F(write),
    { 0 }
};
#undef F

#define E(x) naAddSym(ctx,ns,#x,naNum(SF_##x))
naRef naInit_sndfile(naContext ctx)
{
    naRef ns = naGenLib(ctx, funcs);
    naAddSym(ctx,ns,"WRITE",naNum(SFM_WRITE));
    naAddSym(ctx,ns,"READ",naNum(SFM_READ));
    naAddSym(ctx,ns,"RAWFLOAT",naNum(SF_FORMAT_RAW|SF_FORMAT_FLOAT));
    return ns;
}
#undef E
