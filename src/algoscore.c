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

#include <config.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <time.h>
#include <glib.h>

#include "nasal.h"
#include "utils.h"
//#include "watchdog.h"
#include "gtklib.h"
#include "ige-mac-menu.h"

#define NASTR(s) naStr_fromdata(naNewString(ctx), (s), strlen((s)))

naRef naInit_mathx(naContext ctx);
naRef naInit_playbus(naContext ctx);
naRef naInit_sndfile(naContext ctx);
//naRef naInit_src(naContext ctx);
#ifdef HAVE_CSOUND
naRef naInit_csound(naContext ctx);
#endif
#ifdef HAVE_PCRE
naRef naInit_regex(naContext ctx);
#endif

//void dumpByteCode(naRef codeObj);
/*static naRef f_dump_byte_code(naContext c, naRef me, int argc, naRef* args)
{
    if(!naIsFunc(args[0])) naRuntimeError(c,"not a function\n");
    dumpByteCode(args[0]);
    return naNil();
}
*/

/*char *wd_id = 0;
naContext wd_ctx = 0;

static void watchdog_alert(void) {
    wd_restart();
    if(wd_ctx)
        naRuntimeError(wd_ctx,"%s: Watchdog timeout",wd_id);
}

static naRef f_wd_init(naContext ctx, naRef me, int argc, naRef* args)
{
//    int sec = arg_num(ctx,args,0,"wd_init");
    wd_init(10, watchdog_alert);
    return naNil();
}

static naRef f_wd_feed(naContext ctx, naRef me, int argc, naRef* args)
{
    wd_feed();
    return naNil();
}

static naRef f_wd_set_current(naContext ctx, naRef me, int argc, naRef* args)
{
    if(argc>0) {
        wd_id = naStr_data(naStringValue(ctx,args[0]));
        wd_ctx = ctx;
        wd_feed();
    } else
        wd_ctx = NULL;
    return naNil();
}
*/

#ifdef MAC_INTEGRATION
static naRef f_ige_mac_menu_set_menu_bar(naContext ctx, naRef me, int argc, naRef* args)
{
    ige_mac_menu_set_menu_bar(GTK_MENU_SHELL(OBJARG(0)));
    return naNil();
}
static naRef f_ige_mac_menu_set_quit_menu_item(naContext ctx, naRef me, int argc, naRef* args)
{
    ige_mac_menu_set_quit_menu_item (GTK_MENU_ITEM(OBJARG(0)));
    return naNil();
}
static naRef f_ige_mac_menu_add_menu_item(naContext ctx, naRef me, int argc, naRef* args)
{
    ige_mac_menu_add_app_menu_item (ige_mac_menu_add_app_menu_group(),
                                    GTK_MENU_ITEM (OBJARG(0)), NULL);
    return naNil();
}
#endif

static naRef f_get_tmp_dir(naContext ctx, naRef me, int argc, naRef* args)
{
    return NASTR((char*)g_get_tmp_dir());
}

static naRef f_usleep(naContext c, naRef me, int argc, naRef* args)
{
    unsigned t = args[0].num;
    usleep(t);
    return naNil();
}

static naRef f_print_stderr(naContext c, naRef me, int argc, naRef* args)
{
    int i;
    for(i=0; i<argc; i++) {
        naRef s = naStringValue(c, args[i]);
        if(naIsNil(s)) continue;
        fwrite(naStr_data(s), 1, naStr_len(s), stderr);
    }
    return naNil();
}

static naRef f_print(naContext c, naRef me, int argc, naRef* args)
{
    int i;
    for(i=0; i<argc; i++) {
        naRef s = naStringValue(c, args[i]);
        if(naIsNil(s)) continue;
        g_print("%s",naStr_data(s));
//        fwrite(naStr_data(s), 1, naStr_len(s), stdout);
    }
    return naNil();
}

static naRef f_printerr(naContext c, naRef me, int argc, naRef* args)
{
    int i;
    for(i=0; i<argc; i++) {
        naRef s = naStringValue(c, args[i]);
        if(naIsNil(s)) continue;
        g_printerr("%s",naStr_data(s));
//        fwrite(naStr_data(s), 1, naStr_len(s), stdout);
    }
    return naNil();
}

static naRef print_handler, printerr_handler;

void print_handler_wrapper(const gchar *s) {
    if(!naIsFunc(print_handler)) {
        fprintf(stderr,"print_handler not func!\n");
        return;
    }
    naContext ctx = naNewContext();
    naRef a = NASTR((char*)s);
    naModUnlock();
    naCall(ctx,print_handler,1,&a,naNil(),naNil());
    naModLock();
    if(naGetError(ctx)) {
        gchar *trace = get_stack_trace(ctx);
        fprintf(stderr,"Error in print handler: %s",trace);
        g_free(trace);
    }
    naFreeContext(ctx);
}
void printerr_handler_wrapper(const gchar *s) {
    if(!naIsFunc(printerr_handler)) {
        fprintf(stderr,"printerr_handler not func!\n");
        return;
    }
    naContext ctx = naNewContext();
    naRef a = NASTR((char*)s);
    naModUnlock();
    naCall(ctx,printerr_handler,1,&a,naNil(),naNil());
    naModLock();
    if(naGetError(ctx)) {
        gchar *trace = get_stack_trace(ctx);
        fprintf(stderr,"Error in printerr handler: %s",trace);
        g_free(trace);
    }
    naFreeContext(ctx);
}

static naRef f_set_print_handler(naContext c, naRef me, int argc, naRef* args)
{
    print_handler = args[0];
    naSave(c,print_handler);
    g_set_print_handler(print_handler_wrapper);
//    g_set_printerr_handler(print_handler_wrapper);
    return naNil();
}

static naRef f_set_printerr_handler(naContext c, naRef me, int argc, naRef* args)
{
    printerr_handler = args[0];
    naSave(c,printerr_handler);
    g_set_printerr_handler(printerr_handler_wrapper);
    return naNil();
}

/*
gboolean algoscore_idle_proc(gpointer data) {
    return TRUE;
}
static naRef f_algoscore_initialize(naContext ctx, naRef me, int argc, naRef *args)
{

    //g_timeout_add(10,mindctrl_idle_proc,NULL);
    //g_idle_add(mindctrl_idle_proc,NULL);
    //g_idle_add_full(G_PRIORITY_HIGH_IDLE,kyce_idle_proc,NULL,NULL);
    
    return naNil();
}

static naRef f_algoscore_cleanup(naContext ctx, naRef me, int argc, naRef *args)
{
//    kyce_seq_cleanup();
    return naNil();
}
*/
int main(int argc, char** argv)
{
    FILE* f;
    struct stat fdat;
    char *buf, *script="lib/algoscore-driver.nas";
    naContext ctx;
    naRef code, namespace, *args;
    int errLine, i;
    gchar *appdir = g_path_get_dirname(argv[0]);
    gchar *platform = 0;
    
    g_thread_init(0);

    g_chdir(appdir);
    
    ctx = naNewContext();

    f = fopen(script, "r");
    if(!f) {
        fprintf(stderr, "algoscore: could not open input file: %s\n", script);
        exit(1);
    }
    stat(script, &fdat);
    buf = malloc(fdat.st_size);
    if(fread(buf, 1, fdat.st_size, f) != fdat.st_size) {
        fprintf(stderr, "algoscore: error in fread()\n");
        exit(1);
    }

    code = naParseCode(ctx, NASTR(script), 1, buf, fdat.st_size, &errLine);
    if(naIsNil(code)) {
        fprintf(stderr, "Parse error: %s at line %d\n",
                naGetError(ctx), errLine);
        exit(1);
    }
    free(buf);

    namespace = naInit_std(ctx);

//    naAddSym(ctx, namespace, "app_dir", NASTR(appdir));
    g_free(appdir);

//#ifdef TARGET_MAC_OS
#if (defined(__MACH__) && defined(__APPLE__))
    platform = "macosx";
#else
    platform = "other";
#endif

    naAddSym(ctx, namespace, "platform", NASTR(platform));

#define F(x) naAddSym(ctx, namespace, #x, naNewFunc(ctx, naNewCCode(ctx, f_##x)))
    F(print);
    F(printerr);
    F(print_stderr);
    F(set_print_handler);
    F(set_printerr_handler);
//    F(algoscore_cleanup);
//    F(algoscore_initialize);
//    F(dump_byte_code);
    F(usleep);
    F(get_tmp_dir);
//    F(wd_init);
//    F(wd_feed);
//    F(wd_set_current);
#ifdef MAC_INTEGRATION
    F(ige_mac_menu_set_menu_bar);
    F(ige_mac_menu_set_quit_menu_item);
    F(ige_mac_menu_add_menu_item);
#endif
#undef F

#define M(x) naAddSym(ctx, namespace, #x, naInit_##x (ctx))    
    M(math);
    M(bits);
    M(io);
    M(unix);
    M(utf8);
    M(thread);
//    M(src);
    M(playbus);
    M(sndfile);
#ifdef HAVE_PCRE
    M(regex);
#endif
#ifdef HAVE_SQLITE
    M(sqlite);
#endif
#ifdef HAVE_CSOUND
    M(csound);
#endif

    naAddSym(ctx, namespace, "_gtk", naInit_gtk(ctx));
    M(cairo);

    M(mathx);
#undef M

    code = naBindFunction(ctx, code, namespace);
    args = malloc(sizeof(naRef) * (argc-1));
    for(i=0; i<argc-1; i++)
        args[i] = NASTR(argv[i+1]);
    naCall(ctx, code, argc-1, args, naNil(), naNil());
    
    if(naGetError(ctx)) {
        gchar *trace = get_stack_trace(ctx);
        fprintf(stderr,"Error: %s",trace);
        g_free(trace);
    }

    naFreeContext(ctx);

    return 0;
}
#undef NASTR
