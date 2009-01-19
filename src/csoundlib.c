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

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <config.h>

#ifdef CSOUND_FRAMEWORK
#include <CsoundLib/csound.h>
#include <CsoundLib/cwindow.h>
#else
#include <csound/csound.h>
#include <csound/cwindow.h>
#endif

#include "nasal.h"
#include "utils.h"
#include <locale.h>

#define NASTR(b) naStr_fromdata(naNewString(ctx), (char*)(b), strlen(b))

//static naRef graph_cb, outvalues;
//static naContext cb_ctx;

typedef struct {
    int tag;
    GQueue *msg_queue;
    naRef graph_cb;
    naRef outvalues;
    pthread_mutex_t msg_lock;
    // perhaps also cache software bus pointers here??
} HostData;

typedef struct { CSOUND *cs; } csoundGhost;

static void csoundGhostDestroy(csoundGhost *g)
{
//    int tag = (int) csoundGetHostData(g->cs);
    HostData *data = (HostData*) csoundGetHostData(g->cs);
//    naHash_delete(graph_cb,naNum(data->tag));
//    naHash_delete(outvalues,naNum(data->tag));
    csoundDestroy(g->cs);
    g_queue_free(data->msg_queue);
    pthread_mutex_destroy(&data->msg_lock);
    free(data);
    free(g);
}

static naGhostType csoundGhostType = {
    (void(*)(void*))csoundGhostDestroy, "csound"
};

naRef newCsoundGhost(naContext ctx, CSOUND *cs)
{
    csoundGhost *g = malloc(sizeof(csoundGhost));
    g->cs = cs;
    return naNewGhost(ctx,&csoundGhostType,g);
}

static CSOUND *ghost2csound(naRef r)
{
    if(naGhost_type(r) != &csoundGhostType)
        return NULL;
    return ((csoundGhost*)naGhost_ptr(r))->cs;
}

static CSOUND *arg_csound(naContext c, int argc, naRef *a, int n, const char *f)
{
    CSOUND *cs = ghost2csound(check_arg(c,n,argc,a,f));
    if(!cs) naRuntimeError(c,"Arg %d to %s() not a csound instance",n+1,f);
    return cs;
}

#define CSOUNDARG(n) arg_csound(ctx, argc, args, (n), (__FUNCTION__+2))

//void print_handler_wrapper(const char *s);

/*void csound_msg(CSOUND *cs, int attr, const char *fmt, va_list valist) {
    char buf[4096];
    static int new_line = 1;
    int i;
    buf[4095]=0;
    i = vsnprintf(buf,4095,fmt,valist);
    g_print(new_line?"CSound: %s":"%s",buf);
    new_line=(i>0 && i<4095 && buf[i-1]=='\n')?1:0;
}
*/

static int enable_messages = 1;
static naRef f_enable_messages(naContext ctx, naRef me, int argc, naRef *args) {
    enable_messages = NUMARG(0);
    return naNil();
}

void csound_msg(CSOUND *cs, int attr, const char *fmt, va_list valist) {
    HostData *data = (HostData*) csoundGetHostData(cs);
    char buf[4096];
    if(!enable_messages) return;
    buf[4095]=0;
    vsnprintf(buf,4095,fmt,valist);
    //this is called by csound which is called by nasal, does this mean
    //I need a naModUnlock/Lock around this?
    pthread_mutex_lock(&data->msg_lock);
    g_queue_push_head(data->msg_queue,(gpointer)g_strdup((gchar*)buf));
    pthread_mutex_unlock(&data->msg_lock);    
}

static naRef f_dump_messages(naContext ctx, naRef me, int argc, naRef *args) {
    HostData *data = (HostData*) csoundGetHostData(CSOUNDARG(0));
    gchar *buf;
    naModUnlock();
//    fprintf(stderr,"*** dump_messages locking\n");
    pthread_mutex_lock(&data->msg_lock);
//    fprintf(stderr,"*** dump_messages locked\n");
//    fprintf(stderr,"*** reading %d messages\n",g_queue_get_length(data->msg_queue));
    while((buf=(gchar*)g_queue_pop_tail(data->msg_queue))!=NULL) {
//        fprintf(stderr,"MSG: ",buf);
        g_print("%s",buf);
        g_free(buf);
    }
    pthread_mutex_unlock(&data->msg_lock);
//    fprintf(stderr,"*** dump_messages unlocked\n");
    naModLock();
//    fprintf(stderr,"*** done with messages\n");
}

static void graph_wrapper(CSOUND *cs, WINDAT *wd) {
    HostData *data = (HostData*) csoundGetHostData(cs);
//    int tag = (int) csoundGetHostData(cs);
//    printf("calling graph callback, tag %d\n",tag);
    naRef cb = data->graph_cb;
//    naRef cb = naNil();
//    naHash_get(graph_cb,naNum(data->tag),&cb);
    if(!naIsFunc(cb)) {
        printf("graph callback not func\n");
        return;
    }
    int i;
    naContext ctx = naNewContext();
    naRef a = naNewHash(ctx);
    naRef fdata = naNewVector(ctx);
    naAddSym(ctx,a,"caption",NASTR(wd->caption));
    naAddSym(ctx,a,"npts",naNum(wd->npts));
    naAddSym(ctx,a,"min",naNum(wd->min));
    naAddSym(ctx,a,"max",naNum(wd->max));
    naAddSym(ctx,a,"fdata",fdata);
    for(i=0;i<wd->npts;i++) {
        naVec_append(fdata,naNum(wd->fdata[i]));
    }
    naModUnlock();
    naCall(ctx,cb,1,&a,naNil(),naNil());
    naModLock();
    if(naGetError(ctx)) {
        char *trace = (char *)get_stack_trace(ctx);
        fprintf(stderr,"Error in csound graph handler: %s",trace);
        free(trace);
    }
    naFreeContext(ctx);
}

static naRef f_set_graph_callback(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
    HostData *data = (HostData*) csoundGetHostData(cs);
//    int tag = (int) csoundGetHostData(cs);
//    printf("setting graph callback, tag %d\n",tag);
//    naHash_set(graph_cb,naNum(data->tag),FUNCARG(1));
    data->graph_cb = FUNCARG(1);
    csoundPreCompile(cs);
    csoundSetIsGraphable(cs,1);
    csoundSetDrawGraphCallback(cs,graph_wrapper);
    return naNil();
}

void outvalue_cb(CSOUND *cs, const char *chan, MYFLT val) {
    HostData *data = (HostData*) csoundGetHostData(cs);
//    int tag = (int) csoundGetHostData(cs);
    static float event_id = 0.0;
    //NOTE: this static event_id needs to be moved to host data..

    if(strcmp(chan,"tag")==0) event_id = val;
    else {
        naContext ctx = naNewContext();
        naRef v,h2;
//        naRef h = naNil();
        naRef h = data->outvalues;
        naRef chan_tag = NASTR(chan);
        char buf[64];
        naRef ev_tag;
        
        ev_tag = naNum((int)(0.5 + event_id * 100000) % 100000);
        
//        naHash_get(outvalues,naNum(data->tag),&h);
        

        if(!naHash_get(h,ev_tag,&h2)) {
            h2 = naNewHash(ctx);
            naHash_set(h,ev_tag,h2);
        }

        if(!naHash_get(h2,chan_tag,&v)) {
            v = naNewVector(ctx);
            naHash_set(h2,chan_tag,v);
            
        } else //work-around for first outvalue being zero!
            naVec_append(v,naNum(val));
        naFreeContext(ctx);
    }
}

static naRef f_create(naContext ctx, naRef me, int argc, naRef *args) {
    static cs_initialized=0;
//    int tag = NUMARG(0);
    HostData *data;
    
    if(!cs_initialized) {
        csoundInitialize(0,0,0);
        cs_initialized=1;
    }

    data = (HostData*)malloc(sizeof(HostData));
    data->msg_queue = g_queue_new();
    pthread_mutex_init(&data->msg_lock,0);
    data->tag = NUMARG(0);
    data->graph_cb = naNil();
    data->outvalues = naNil();
    CSOUND *cs = csoundCreate((void*)data);
//    CSOUND *cs = csoundCreate((void*)tag);
    csoundSetMessageCallback(cs, csound_msg);
    csoundSetOutputValueCallback(cs, outvalue_cb);
    return newCsoundGhost(ctx,cs);
}

static naRef f_compile(naContext ctx, naRef me, int argc, naRef *args) {
    int res, i, j, sz;
    char **cs_argv;
    CSOUND *cs = CSOUNDARG(0);
    naRef v = VECARG(1);
    sz = naVec_size(v)+1;
    cs_argv = malloc(sizeof(char *) * sz);
    cs_argv[0] = "as_cs";
    for(i=1;i<sz;i++) {
        naRef a = naStringValue(ctx,naVec_get(v,i-1));
        if(!naIsString(a)) {
            free(cs_argv);
            naRuntimeError(ctx,"csound.compile(cs,argv): non-string value in argv");
        }
        cs_argv[i] = naStr_data(a);
    }
    setlocale(LC_ALL, "C");
    res = csoundCompile(cs,sz,cs_argv);
    free(cs_argv);
    return naNum(res);
}

static naRef f_reset(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
    csoundReset(cs);
    return naNil();
}

static naRef f_perform_ksmps(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
//    naModUnlock();
    int res = csoundPerformKsmps(cs);
//    naModLock();
    return naNum(res);
}

static naRef f_score_event(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0); //ghost2csound(args[0]);
    char type = NUMARG(1);
    MYFLT *parms;
    int i;
    naRef vec = VECARG(2);
    int sz = naVec_size(vec);
    parms = malloc(sizeof(MYFLT)*sz);
    
    for(i=0;i<sz;i++)
        parms[i]=naNumValue(naVec_get(vec,i)).num;
    csoundScoreEvent(cs, type, parms, sz);
    free(parms);
    return naNil();
}

// Do this through a ghost handle instead of getting the channel ptr each time?
// may be especially more efficient for audio channels...
static naRef f_kchannel_write(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
    char *chan = naStr_data(STRARG(1));
    MYFLT *val;
    csoundGetChannelPtr(cs, &val, chan, CSOUND_INPUT_CHANNEL | CSOUND_CONTROL_CHANNEL);
    *val = NUMARG(2);
    return naNil();
}

static naRef f_get_kr(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
    return naNum(csoundGetKr(cs));
}

static naRef f_get_sr(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
    return naNum(csoundGetSr(cs));
}

static naRef f_get_nchnls(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
    return naNum(csoundGetNchnls(cs));
}

static naRef f_get_score_time(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
    return naNum(csoundGetScoreTime(cs));
}

static naRef f_list_channels(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
    CsoundChannelListEntry *lst;
    int i, chans = csoundListChannels(cs, &lst);
    naRef v = naNewVector(ctx);
    for(i=0;i<chans;i++) {
        CsoundChannelListEntry *ch = &lst[i];
        naRef h = naNewHash(ctx);
        char *t;
        switch(ch->type & CSOUND_CHANNEL_TYPE_MASK) {
            case CSOUND_CONTROL_CHANNEL:    t="control"; break;
            case CSOUND_AUDIO_CHANNEL:      t="audio"; break;
            case CSOUND_STRING_CHANNEL:     t="string"; break;
        }
        naAddSym(ctx,h,"name",NASTR(ch->name));
        naAddSym(ctx,h,"type",NASTR(t));
        naAddSym(ctx,h,"input",naNum(ch->type & CSOUND_INPUT_CHANNEL?1:0));
        naAddSym(ctx,h,"output",naNum(ch->type & CSOUND_OUTPUT_CHANNEL?1:0));
        naVec_append(v,h);
    } 
    csoundDeleteChannelList(cs,lst);
    return v;
}

static naRef f_rewind_score(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
    csoundRewindScore(cs);
    return naNil();
}

/*static naRef f_get_outvalues(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
    HostData *data = (HostData*) csoundGetHostData(cs);
    int tag = (int) csoundGetHostData(cs);
    naRef h = naNil();
    naHash_get(outvalues,naNum(data->tag),&h);
    return h;
    
}
*/

static naRef f_clear_outvalues(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
    HostData *data = (HostData*) csoundGetHostData(cs);
//    int tag = (int) csoundGetHostData(cs);
//    naHash_set(outvalues,naNum(data->tag),naNewHash(ctx));
    data->outvalues = args[1];
    return naNil();
}

static naRef f_list_opcodes(naContext ctx, naRef me, int argc, naRef *args) {
    CSOUND *cs = CSOUNDARG(0);
    opcodeListEntry *ops;
    int i,n;
    naRef list;
    
    n = csoundNewOpcodeList(cs,&ops);
    if(n<0) naRuntimeError(ctx,"Could not get csound opcode list");
    
    list = naNewVector(ctx);
    for(i=0;i<n;i++) {
        opcodeListEntry *op = &ops[i];
        naRef v = naNewVector(ctx);
        naVec_append(v,NASTR(op->opname));
        naVec_append(v,NASTR(op->outypes));
        naVec_append(v,NASTR(op->intypes));
        naVec_append(list,v);
    }
    
    csoundDisposeOpcodeList(cs,ops);
    return list;
}

#define F(x) { #x, f_##x }
static naCFuncItem funcs[] = {
    F(enable_messages),
    F(list_opcodes),
    F(create),
    F(compile),
    F(reset),
    F(perform_ksmps),
    F(score_event),
    F(kchannel_write),
    F(get_kr),
    F(get_sr),
    F(get_nchnls),
    F(get_score_time),
    F(set_graph_callback),
    F(list_channels),
    F(rewind_score),
    F(clear_outvalues),
//    F(get_outvalues),
    F(dump_messages),
    { 0 }
};
#undef F

naRef naInit_csound(naContext ctx)
{
    naRef ns = naGenLib(ctx, funcs);
//    graph_cb = naNewHash(ctx);
//    naSave(ctx,graph_cb);
//    outvalues = naNewHash(ctx);
//    naSave(ctx,outvalues);
//    cb_ctx = naNewContext();

//    msg_queue = g_queue_new();

    return ns;
}
