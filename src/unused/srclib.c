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

// This file is currently not used.

#include <stdio.h>
#include <stdlib.h>
#include <samplerate.h>
#include "nasal.h"

static naRef f_convert(naContext ctx, naRef me, int argc, naRef *args) {
    naRef na_in = args[0]; //vector
    int size = naVec_size(na_in);
    naRef na_out = naNewVector(ctx);
    int newsize = naNumValue(args[1]).num;
    int type = argc>2?naNumValue(args[2]).num:SRC_LINEAR;
    int chans = argc>3?naNumValue(args[3]).num:1;
    int err, i;
    SRC_DATA src;
    
    src.input_frames = size;
    src.data_in = malloc(sizeof(float)*size);
    src.output_frames = newsize;
    src.data_out = malloc(sizeof(float)*newsize);
    src.src_ratio = (double)newsize/(double)size;
    
    printf("src ratio: %g\n",src.src_ratio);
    
    for(i=0;i<size;i++)
        src.data_in[i] = naNumValue(naVec_get(na_in,i)).num;

    err = src_simple(&src, type, chans);
    
    free(src.data_in);
    
    if(err) {
        free(src.data_out);
        naRuntimeError(ctx,"src_simple: %s\n",src_strerror(err));
    }
    
    naVec_setsize(na_out, newsize);
    for(i=0;i<newsize;i++)
        naVec_set(na_out,i,naNum(src.data_out[i]));
        
    free(src.data_out);
    
    return na_out;
}

#define F(x) { #x, f_##x }
static naCFuncItem funcs[] = {
    F(convert),
    { 0 }
};
#undef F

#define E(x) naAddSym(ctx,ns,#x,naNum(SRC_##x))
naRef naInit_src(naContext ctx)
{
    naRef ns = naGenLib(ctx, funcs);
    E(SINC_BEST_QUALITY);
    E(SINC_MEDIUM_QUALITY);
    E(SINC_FASTEST);
    E(ZERO_ORDER_HOLD);
    E(LINEAR);
    return ns;
}
#undef E
