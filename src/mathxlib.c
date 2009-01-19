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

#include <math.h>
#include <time.h>
#include <stdlib.h>
#include "nasal.h"

#define NUMARG(x) (naNumValue(args[x]).num)

static naRef f_rand(naContext ctx, naRef me, int argc, naRef *args) {
    return naNum(drand48());
}

static naRef f_seed(naContext ctx, naRef me, int argc, naRef *args) {
    if(argc>0) srand48(NUMARG(0));
    else       srand48(time(NULL));
    return naNil();
}

static naRef f_ceil(naContext ctx, naRef me, int argc, naRef *args) {
    return argc>0?naNum(ceil(NUMARG(0))):naNil();
}

static naRef f_log2(naContext ctx, naRef me, int argc, naRef *args) {
    return argc>0?naNum(log2(NUMARG(0))):naNil();
}

static naRef f_lshift(naContext ctx, naRef me, int argc, naRef *args) {
    return argc>1?naNum((int)NUMARG(0)<<(int)NUMARG(1)):naNil();
}
static naRef f_rshift(naContext ctx, naRef me, int argc, naRef *args) {
    return argc>1?naNum((int)NUMARG(0)<<(int)NUMARG(1)):naNil();
}

static naRef f_mod(naContext ctx, naRef me, int argc, naRef *args) {
    double x = fmod(NUMARG(0),NUMARG(1));
//    if(x < 0) x += fabs(NUMARG(1));
    return argc>1?naNum(x):naNil();
}

static naRef f_pow(naContext ctx, naRef me, int argc, naRef *args) {
    return argc>1?naNum(pow(NUMARG(0),NUMARG(1))):naNil();
}

static naRef f_fact(naContext ctx, naRef me, int argc, naRef *args) {
    unsigned long long x=argc>0?NUMARG(0):0, n=x;
    if(n<1) return naNum(0);
    while(--n>1) x*=n;
    return naNum(x);
}

static naRef f_permute(naContext ctx, naRef me, int argc, naRef *args) {
    naRef v = args[0];
    naRef r = naNewVector(ctx);

    unsigned j,i,x,N=naVec_size(v);
    unsigned p[N];
    naRef t,a[N];

    i=N;
    while(i--) {
        a[i]=naVec_get(v,i); //copy vec
        p[i]=0;
    }

    naVec_append(r,v);

    i = 1;
    while(i<N) {
        if(p[i]<i) {
            naRef sv = naNewVector(ctx);
            j=i%2*p[i];
            t=a[j];
            a[j]=a[i];
            a[i]=t;
            for(x=0;x<N;x++)
                naVec_append(sv, a[x]);
            naVec_append(r,sv);
            p[i]++;
            i=1;
        } else {
            p[i]=0;
            i++;
        }
    }

    return r;
}

// generate a random number between 0.0 to 1.0, from the input integer
// between 0 and 4294967295 (0xffffffff). Same input gives same value...
static naRef f_noise(naContext ctx, naRef me, int argc, naRef *args) {
    int x = argc>0?NUMARG(0):0;
    double z;
    x = (x<<13)^x;
    z = (1.0-((x*(x*x*15731+789221)+1376312589)&0x7fffffff)/1073741824.0);
    return naNum(z*0.5+0.5);
}

#define F(x) { #x, f_##x }
static naCFuncItem funcs[] = {
    F(rand),
    F(seed),
    F(ceil),
    F(mod),
    F(pow),
    F(fact),
    F(permute),
    F(noise),
    F(log2),
    F(lshift),
    F(rshift),
    { 0 }
};
#undef F

naRef naInit_mathx(naContext ctx) {
    srand48(time(NULL));
    return naGenLib(ctx,funcs);
}
