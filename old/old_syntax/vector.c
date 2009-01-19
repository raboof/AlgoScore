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

#include "nasal.h"
#include "data.h"

static struct VecRec* newvecrec(struct VecRec* old)
{
    int i, oldsz = old ? old->size : 0, newsz = 1 + ((oldsz*3)>>1);
    struct VecRec* vr = naAlloc(sizeof(struct VecRec) + sizeof(naRef) * newsz);
    if(oldsz > newsz) oldsz = newsz; // race protection
    vr->alloced = newsz;
    vr->size = oldsz;
    for(i=0; i<oldsz; i++)
        vr->array[i] = old->array[i];
    return vr;
}

static void resize(struct naVec* v)
{
    struct VecRec* vr = newvecrec(v->rec);
    naGC_swapfree((void**)&(v->rec), vr);
}

void naVec_gcclean(struct naVec* v)
{
    naFree(v->rec);
    v->rec = 0;
}

naRef naVec_get(naRef v, int i)
{
    if(IS_VEC(v)) {
        struct VecRec* r = PTR(v).vec->rec;
        if(r) {
            if(i < 0) i += r->size;
            if(i >= 0 && i < r->size) return r->array[i];
        }
    }
    return naNil();
}

void naVec_set(naRef vec, int i, naRef o)
{
    if(IS_VEC(vec)) {
        struct VecRec* r = PTR(vec).vec->rec;
        if(r && i >= r->size) return;
        r->array[i] = o;
    }
}

int naVec_size(naRef v)
{
    if(IS_VEC(v)) {
        struct VecRec* r = PTR(v).vec->rec;
        return r ? r->size : 0;
    }
    return 0;
}

int naVec_append(naRef vec, naRef o)
{
    if(IS_VEC(vec)) {
        struct VecRec* r = PTR(vec).vec->rec;
        while(!r || r->size >= r->alloced) {
            resize(PTR(vec).vec);
            r = PTR(vec).vec->rec;
        }
        r->array[r->size] = o;
        return r->size++;
    }
    return 0;
}

void naVec_setsize(naRef vec, int sz)
{
    int i;
    struct VecRec* v = PTR(vec).vec->rec;
    struct VecRec* nv = naAlloc(sizeof(struct VecRec) + sizeof(naRef) * sz);
    nv->size = sz;
    nv->alloced = sz;
    for(i=0; i<sz; i++)
        nv->array[i] = (v && i < v->size) ? v->array[i] : naNil();
    naGC_swapfree((void**)&(PTR(vec).vec->rec), nv);
}

naRef naVec_removelast(naRef vec)
{
    naRef o;
    if(IS_VEC(vec)) {
        struct VecRec* v = PTR(vec).vec->rec;
        if(!v || v->size == 0) return naNil();
        o = v->array[v->size - 1];
        v->size--;
        if(v->size < (v->alloced >> 1))
            resize(PTR(vec).vec);
        return o;
    }
    return naNil();
}
