#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <termios.h>
#include <glib.h>

#include "nasal.h"
#include "hardware.h"
#include "utils.h"
#include "firmware/commands.h"

/*
    TODO:
    
    support multiple ports, each port need separate input_cb, cb_ctx, watch_id, state, iochan, etc..
    either keep a naHash with "/dev/foo" as keys, or use a naGhost returned
    by connect(). Or perhaps just a numbered table, then use these numbers in the
    device setup.
    One device is the master device, which gets the start/stop commands. The others
    have their hardware interrupt hooked to the masters clock line...
    
*/

static naRef input_cb;
static naContext cb_ctx;
GIOChannel *gch = 0;
StreamState *state;
gint watch_id;

static naRef chkarg(naContext ctx, int n, int ac, naRef *av, const char* fn)
{
    if(n >= ac) naRuntimeError(ctx, "not enough arguments to %s", fn);
    return av[n];
}
static naRef strarg(naContext ctx, int n, int ac, naRef *av, const char* fn)
{
    naRef r = naStringValue(ctx, chkarg(ctx, n, ac, av, fn));
    if(naIsNil(r)) naRuntimeError(ctx, "arg %d to %s not string", n+1, fn);
    return r;
}
static naRef funcarg(naContext ctx, int n, int ac, naRef *av, const char* fn)
{
    naRef r = chkarg(ctx, n, ac, av, fn);
    if(!naIsFunc(r))
        naRuntimeError(ctx, "arg %d to %s not function", n+1, fn);
    return r;
}
static naRef vecarg(naContext ctx, int n, int ac, naRef *av, const char* fn)
{
    naRef r = chkarg(ctx, n, ac, av, fn);
    if(!naIsVector(r))
        naRuntimeError(ctx, "arg %d to %s not vector", n+1, fn);
    return r;
}
static double numarg(naContext ctx, int n, int ac, naRef *av, const char* fn)
{
    naRef r = naNumValue(chkarg(ctx, n, ac, av, fn));
    if(naIsNil(r)) naRuntimeError(ctx, "arg %d to %s not number", n+1, fn);
    return r.num;
}
#define STRARG(n) strarg(ctx, (n), argc, args, (__func__+2))
#define FUNCARG(n) funcarg(ctx, (n), argc, args, (__func__+2))
#define NUMARG(n) numarg(ctx, (n), argc, args, (__func__+2))
#define VECARG(n) vecarg(ctx, (n), argc, args, (__func__+2))

static StreamState * new_stream_state(void) {
    StreamState * p = g_new(StreamState,1);
    p->pos = -1;
    p->get_channel = 0;
    p->escape = 0;
    return p;
}

int open_serial_port(char *dev)
{
    int fd = open(dev, O_RDWR | O_NOCTTY);// | O_NDELAY);
    if (fd != -1) {
        struct termios options;
        speed_t baud = B115200;

//        fcntl(fd, F_SETFL, 0); //what does this do?
    //    fcntl(fd, F_SETFL, FNDELAY);

        tcgetattr(fd, &options);

        cfsetispeed(&options, baud);
        cfsetospeed(&options, baud);
        cfmakeraw(&options);
/*
        options.c_cflag |= (CLOCAL | CREAD);
        options.c_cflag &= ~PARENB;
        options.c_cflag &= ~CSTOPB;
        options.c_cflag &= ~CSIZE;
        options.c_cflag |= CS8;

//        options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
        options.c_lflag &= ~(ICANON | ECHO | ISIG);
        options.c_oflag &= ~OPOST;
//        options.c_iflag &= ~(IXON | IXOFF | IXANY);
//        options.c_iflag &= ~(ICRNL | INLCR | IGNCR);
        options.c_iflag &= ~(ICRNL | INLCR | IGNCR | IXON | IXOFF);
*/        
        tcsetattr(fd, TCSANOW, &options);
    }
    return (fd);
}

static void do_connect_cb(int x) {
    naRef cb = naVec_get(input_cb,1);
    naRef arg = naNum(x);
//    is_connected = x;
    naModUnlock();
    naCall(cb_ctx,cb,1,&arg,naNil(),naNil());
    naModLock();
    if(naGetError(cb_ctx)) {
        gchar *trace = get_stack_trace(cb_ctx);
        g_printerr("Error in connect callback: %s",trace);
        g_free(trace);
    }
}

static void finish_packet(StreamState *state) {
    naRef cb = naVec_get(input_cb,0);
    
//    if(state->pos<0 || naIsNil(cb)) return;
    if(state->pos<0) return;
    
    if(naIsNil(cb)) {
        int i;
        g_print("\nChan: %d Size: %d\n",state->channel,state->pos);
        for(i=0;i<state->pos;i++) {
            g_print("%02X ",state->buf[i]);
            if((i+1)%16==0) g_print("\n");
        }
        return;
    }
    naRef *args = malloc(sizeof(naRef)*2);
    args[0] = naNum(state->channel);
    args[1] = naStr_fromdata(naNewString(cb_ctx), state->buf, state->pos);

    naModUnlock();
    naCall(cb_ctx,cb,2,args,naNil(),naNil());
    naModLock();
    if(naGetError(cb_ctx)) {
        gchar *trace = get_stack_trace(cb_ctx);
        g_printerr("Error in input callback: %s",trace);
        g_free(trace);
    }
    free(args);
}

static void start_new_packet(StreamState *state, int chan) {
    state->escape = 0;
    state->get_channel = 0;
    state->pos = 0;
    state->channel = chan;
}

static void append_to_packet(StreamState *state, guchar c) {
    state->escape = 0;
    if(state->pos<0) return;
    state->buf[state->pos++] = c;
    if(state->pos == MAX_PAC_SIZE) {
        g_printerr("PACKET OVERFLOW\n");
        state->pos = 0;
    }
}

//void handle_special_packet(GIOChannel *src, guchar c) {
//}

static gboolean watch(GIOChannel *src, GIOCondition cond, gpointer data) {
    gint i;
    guchar c;
//    StreamState * state = data;
    g_io_channel_read_chars(src,&c,1,&i,NULL);
    if(i<1) {
        g_print("device disconnected\n");
        do_connect_cb(0);
        g_free(state);
//        g_source_remove(watch_id);
        g_io_channel_unref(src);
        gch = 0;
        return FALSE;
    }

    if(state->get_channel) {
        if(c!=0xFF) start_new_packet(state,c);
    } else if(c==0xFF && !state->escape) {
        finish_packet(state);
//        g_io_channel_read_chars(src,&c,1,&i,NULL);
//        start_new_packet(state,c);
        state->get_channel = 1;
    } else if(c==0xFE && !state->escape)
        state->escape = 1;
    else
        append_to_packet(state,c);
    
    return TRUE;
}

void send_cmd(GIOChannel *src, guchar cmd) {
    gint i;
    g_io_channel_write_chars(gch,&cmd,1,&i,NULL);
    g_io_channel_flush(gch,NULL);
    if(i<1) g_printerr("Could not send command\n");
}

static naRef f_append_data(naContext ctx, naRef me, int argc, naRef* args) {
    naRef v = args[0];
    guchar *data = argc>1?naStr_data(args[1]):0;
    int wordsize = NUMARG(2);
    int i;
    if(!data) return naNil();
    
    switch(wordsize) {
        case 1:
            for(i=0;i<naStr_len(args[1]);i++)
                naVec_append(v,naNum(data[i]));
        break;
        case 2:
            for(i=0;i<naStr_len(args[1]);i+=2)
                naVec_append(v,naNum(data[i]|(data[i+1]<<8)));
        break;
        case 3:
            for(i=0;i<naStr_len(args[1]);i+=3)
                naVec_append(v,naNum(data[i]|(data[i+1]<<8)|(data[i+2]<<16)));
        break;
        case 4:
            for(i=0;i<naStr_len(args[1]);i+=4)
                naVec_append(v,naNum(data[i]|(data[i+1]<<8)|(data[i+2]<<16)|(data[i+3]<<24)));
        break;
    }
        
    return naNil();
}

static naRef f_connect(naContext ctx, naRef me, int argc, naRef* args) {
    char *dev = naStr_data(STRARG(0));
    if(gch) {
        g_print("Already connected\n");
        return naNum(0);
    }
    int fd = open_serial_port(dev);
    if(fd<0) {
        g_printerr("Could not open port: %s\n",dev);
        return naNum(0);
    }
    g_print("Opened port %s\n",dev);
    do_connect_cb(1);
    gch = g_io_channel_unix_new(fd);
    g_io_channel_set_encoding(gch,NULL,NULL);
    g_io_channel_set_buffered (gch, FALSE);
    g_io_channel_set_close_on_unref(gch,1);
    state = new_stream_state();
    watch_id = g_io_add_watch(gch,G_IO_IN|G_IO_PRI,watch,0);
    return naNum(1);
}

static naRef f_disconnect(naContext ctx, naRef me, int argc, naRef* args) {
    g_free(state);
    g_source_remove(watch_id);
    g_io_channel_unref(gch);
    gch = 0;
    do_connect_cb(0);
    return naNil();
}

static naRef f_set_input_cb(naContext ctx, naRef me, int argc, naRef *args)
{
    naVec_set(input_cb,0,args[0]);
    return naNil();
}

static naRef f_set_connect_cb(naContext ctx, naRef me, int argc, naRef *args)
{
    naVec_set(input_cb,1,args[0]);
    return naNil();
}

static naRef f_send_byte(naContext ctx, naRef me, int argc, naRef *args)
{
    send_cmd(gch,NUMARG(0));
    return naNil();
}
static naRef f_send_short(naContext ctx, naRef me, int argc, naRef *args)
{
    unsigned int val = NUMARG(0);
    send_cmd(gch,val&0xFF);
    send_cmd(gch,val>>8);
    return naNil();
}

#define F(x) { #x, f_##x }
static naCFuncItem funcs[] = {
    F(connect),
    F(disconnect),
    F(set_input_cb),
    F(set_connect_cb),
    F(append_data),
    F(send_byte),
    F(send_short),
    { 0 }
};
#undef F

#define E(x) naAddSym(ctx,ns,#x,naNum(x))
naRef naInit_hardware(naContext ctx)
{
    naRef ns = naGenLib(ctx, funcs);
    
    E(CMD_HELLO);
    E(CMD_START);
    E(CMD_STOP);
    E(CMD_SETUP_INS);
    E(CMD_SETUP_OUTS);
    E(CMD_PUT_EVENT);
    
    E(NFO_PKTSIZE_MISMATCH);
    E(NFO_BUFFER_OVERRUN);
    E(NFO_CLOCK);
    E(NFO_HELLO);
    E(NFO_TIMER_OVERLAP);
    E(NFO_QUEUE_FULL);
    E(NFO_QUEUE_AVAILABLE);
    
    E(DUMMY_EVENT_CHAN);
    
    input_cb = naNewVector(ctx);
    naVec_append(input_cb,naNil());
    naVec_append(input_cb,naNil());
    naSave(ctx,input_cb);
    cb_ctx = naNewContext();
    return ns;
}
#undef E
