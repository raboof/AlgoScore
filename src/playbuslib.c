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

#define _GNU_SOURCE

#include <config.h>

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>
#include <math.h>
#include <float.h>
#include <sndfile.h>
#include <pthread.h>
#include <glib.h>
#include <signal.h>
#include <time.h>

#include <jack/jack.h>
#include <jack/ringbuffer.h>

#if !(_POSIX_TIMERS > 0)
#include <sys/time.h>
#endif

/*#if !(_POSIX_TIMERS > 0)
#warning No POSIX timers on this system, disabling OSC support
#undef LIBLO_FOUND
#endif*/

#ifdef LIBLO_FOUND
#include <lo/lo.h>
#else
//dummy definitions
typedef void* lo_message;
typedef void* lo_address;
lo_message lo_message_new(void) { return 0; }
lo_address lo_address_new (const char *host, const char *port) { return 0; }
void lo_message_free(lo_message msg) {}
void lo_address_free(lo_address adr) {}
#endif

#include "nasal.h"
#include "utils.h"

#define NASTR(b) naStr_fromdata(naNewString(ctx), (char*)(b), strlen(b))
#define RB_SIZE 32768
#define EV_ALLOC_CHUNK 64
#define MAX_CHANS 32

//#define OSC_TICK_MS 1

/*
TODO

CLEAN UP THIS MESS ;-)

problem, now disk_thread handles some admin tasks like adding new regions,
but the disk_thread is never run if we couldn't create a jack client (who runs
process()).
- put region management in UI thread (skip the new_regions stuff)
- think some more about bus deletion, how to make sure it's not in the list
when ghostdestroy comes for harvest?

We should be able to create a bus and export audio/midi even if compiled without
JACK!

have a region->length and set to min(info.frames, desired_region_length)
stop playing when this length is reached.
also use this when finding region at locate point..
NOTE: libsndfile already does stop at info.frames, so we just need to
check for desired_region_length, which could be set to zero to use the full
file length...

have a region->ofs to add to all sf_seek()'s...

export_bus(b, filename)
 it's just a matter of concatenuating the regions, and padding with zero in
 between...
 we should probably share code with disk_thread...
 choose format, major and subtype.
 get_formats() returns a hash of major formats:
   name (string), extension (string), subtypes (vector of strings).
 see sf_list_format.c
 
export_mix(busses[], channels, filename)
 mix down busses to file,
 perhaps also have a bus.pan, or pass this in a list to this function...
 (if we have a bus.pan we might want a mix jack output also)
or... separate jack ports from the busses, and have a separate list of
ports, and each bus chooses which port it wants to be mixed to?
then export to file uses the same audio as the ports..

but, otoh, jack already does mixing and it's an easy way to handle the
connections.

support jack transport:
f_play(), f_stop(), f_locate() should call the jack_transport functions.
process() should poll the jack_transport to get state.
register a slow-sync callback to set locate_pos and do_locate().. then use
try_lock instead of lock for midi, and return false if try_lock failed. (??)

if regions are overlapping, mix them together. keep a linked list in
disk_thread of current regions, which are mixed together into the ringbuffer.

now there's one ringbuffer per bus, would it be better to have one global?
either way, would it be better to allocate N frames per channel?
now a monobus has the same ringbuf size as an 8 channel bus..

Use g_atomic_int_set/get() for the thread-shared flags?
*/

typedef struct {
    jack_nframes_t time;
    unsigned char data[4];
    int size;
} MidiEvent;

typedef struct {
    MidiEvent *events;
    size_t n_allocated;
    size_t n_events;
    jack_port_t *port;
    unsigned int pos;
} MidiBus;

//unsigned long osc_ticks;

typedef struct {
    double time;
    char *path;
    lo_message msg;
} OSCEvent;

typedef struct {
    OSCEvent *events;
    size_t n_allocated;
    size_t n_events;
    lo_address addr;
    unsigned int pos;
} OSCBus;

/*typedef struct _region {
    char *file;
    SNDFILE *sf;
    SF_INFO info;
    jack_nframes_t start;
    jack_nframes_t ofs;
} Region;*/

typedef struct {
    char *file;
    SNDFILE *sf;
    SF_INFO info;

/*    int nregions;
    Region *region;
    int new_nregions;
    Region *new_region;*/
    int nports;
    jack_port_t **port;
    jack_ringbuffer_t *rb;
//    int curr_region;
    int silence;
    float amp;
    jack_nframes_t read_pos;
    int sr_div, sr_div_count;
    jack_default_audio_sample_t buf[MAX_CHANS];
} AudioBus;

GSList *busses = NULL;
GSList *midi_busses = NULL;

pthread_mutex_t midi_lock = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t disk_thread_lock = PTHREAD_MUTEX_INITIALIZER;
pthread_t disk_thread_id = 0;
pthread_cond_t data_ready = PTHREAD_COND_INITIALIZER;
pthread_rwlock_t busses_lock;

GSList *osc_busses = NULL;
pthread_mutex_t osc_lock = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t osc_start = PTHREAD_COND_INITIALIZER;
pthread_t osc_thread_id = 0;

#define BUS_RLOCK() pthread_rwlock_rdlock(&busses_lock)
#define BUS_TRYRLOCK() pthread_rwlock_tryrdlock(&busses_lock)
#define BUS_WLOCK() pthread_rwlock_wrlock(&busses_lock)
#define BUS_UNLOCK() pthread_rwlock_unlock(&busses_lock)

jack_nframes_t play_pos, locate_pos, end_pos;
double locate_pos_sec;
volatile int locate_was_set = 0;
volatile int can_process = 0;
volatile int playing = 0;
volatile int playing_osc = 0;

const size_t sample_size = sizeof(jack_default_audio_sample_t);

jack_client_t *client = 0;
jack_client_t *old_client = 0;

jack_nframes_t samplerate = 44100; //default if we couldn't connect to jack

/*void free_regions(AudioBus *b) {
    int i;
    for(i=0;i<b->nregions;i++) {
        Region *r = &b->region[i];
        sf_close(r->sf);
        free(r->file);
    }
//    b->curr_region = 0;
    b->nregions = 0;
    b->curr_region = -1;
    free(b->region);
    b->region = 0;
}*/


#if !(_POSIX_TIMERS > 0)
#warning No POSIX timers on this system, using gettimeofday()
static int fake_clock_gettime(struct timespec *ts)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    ts->tv_sec = tv.tv_sec;
    ts->tv_nsec = tv.tv_usec * 1000;
    return 0;
}
#define clock_gettime(a,b) fake_clock_gettime(b)
#endif

void remove_bus(AudioBus *b) {
    BUS_WLOCK();
    
    busses = g_slist_remove(busses,(gpointer)b);

//    free_regions(b);
    if(client) {
        int i;
        for(i=0;i<b->nports;i++) {
            g_print("unregistering jack port %s\n", jack_port_name(b->port[i]));
            jack_port_unregister(client,b->port[i]);
        }
    }
    if(b->file) g_free(b->file);
    if(b->sf) sf_close(b->sf);
    b->nports = 0;
    free(b->port);
    b->port = 0;
    jack_ringbuffer_free(b->rb);
    b->rb = 0;

    BUS_UNLOCK();
}

void remove_midibus(MidiBus *b) {
    pthread_mutex_lock(&midi_lock);
    midi_busses = g_slist_remove(midi_busses,(gpointer)b);
    if(client && b->port) {
        g_print("unregistering jack port %s\n", jack_port_name(b->port));
        jack_port_unregister(client,b->port);
    }
   
    free(b->events);
    b->events=0;
    b->n_allocated=0;
    b->n_events=0;
    
    pthread_mutex_unlock(&midi_lock);
}

void remove_oscbus(OSCBus *b) {
    int i;
    pthread_mutex_lock(&osc_lock);
    osc_busses = g_slist_remove(osc_busses,(gpointer)b);
    for(i=0;i<b->n_events;i++) {
        OSCEvent *ev = &b->events[i];
        lo_message_free(ev->msg);
        free(ev->path);
    }
    free(b->events);
   
    b->events=0;
    b->n_allocated=0;
    b->n_events=0;
    lo_address_free(b->addr);
    pthread_mutex_unlock(&osc_lock);
}

int process(jack_nframes_t nframes, void *arg)
{
    int i, f;
    jack_position_t pos;
    if (!can_process) return 0;

    playing = jack_transport_query(client,&pos)==JackTransportRolling;
//    play_pos = pos.frame;

#ifndef JACK_OLD_MIDI
    if(pthread_mutex_trylock (&midi_lock) == 0) {
        GSList *ml = midi_busses;
        while(ml) {
            MidiBus *b = (MidiBus*) ml->data;
            ml = g_slist_next(ml);

            void *buf = jack_port_get_buffer(b->port, nframes);

#ifdef JACK_STABLE_MIDI
            jack_midi_clear_buffer(buf);
#else
            jack_midi_clear_buffer(buf, nframes);
#endif
            while(playing && b->pos<b->n_events) {
                MidiEvent *ev = &b->events[b->pos];
#ifdef JACK_STABLE_MIDI
                if(jack_midi_max_event_size(buf) < ev->size) {
#else
                if(jack_midi_max_event_size(buf, nframes) < ev->size) {
#endif
                    fprintf(stderr,"process(): midi buffer full\n");
                    //midi_buffer_overflows++;
                    break;
                }
                if(ev->time < play_pos+nframes) {
                    jack_nframes_t time = ev->time<play_pos?0:ev->time-play_pos;
#ifdef JACK_STABLE_MIDI
                    jack_midi_event_write(buf, time, ev->data, ev->size);
#else
                    jack_midi_event_write(buf, time, ev->data, ev->size, nframes);
#endif
                } else
                    break;
                b->pos++;
            }
        }
        pthread_mutex_unlock (&midi_lock);
    }
#endif

    if(BUS_TRYRLOCK()==0) {
        GSList *l = busses;
        while(l) {
            AudioBus *b = (AudioBus*) l->data;
            l = g_slist_next(l);
            jack_default_audio_sample_t readbuf[b->nports];
            jack_default_audio_sample_t *out[b->nports];
            for(i=0;i<b->nports;i++)
                out[i]=jack_port_get_buffer(b->port[i], nframes);
            for(f=0;f<nframes;f++) {
                size_t sz = sample_size*b->nports;
                jack_ringbuffer_read(b->rb, (void*)readbuf, sz);
                for(i=0;i<b->nports;i++)
                    out[i][f] = playing?readbuf[i]*b->amp:0;
            }
        }
        BUS_UNLOCK();
    }
    // wake up the disk thread to read more data
    if (pthread_mutex_trylock (&disk_thread_lock) == 0) {
        pthread_cond_signal (&data_ready);
        pthread_mutex_unlock (&disk_thread_lock);
    }
    
    if(playing) {
        play_pos += nframes;
        if(play_pos >= end_pos) {
            playing = 0;
        }
    }
    
    return 0;      
}

/*void try_reopen(AudioBus *b, Region *r) {
    sf_close(r->sf);
    r->sf = sf_open(r->file,SFM_READ,&(r->info));
}*/
void try_reopen(AudioBus *b) {
    sf_close(b->sf);
    if(b->file)
        b->sf = sf_open(b->file,SFM_READ,&(b->info));
}

/*static void add_byte(struct smf_track *track, unsigned char byte)
{
	if (track->cur_buf_size >= BUFFER_SIZE) {
		track->cur_buf->next = calloc(1, sizeof(struct buffer));
		if (!track->cur_buf->next)
			fatal("out of memory");
		track->cur_buf = track->cur_buf->next;
		track->cur_buf_size = 0;
	}

	track->cur_buf->buf[track->cur_buf_size++] = byte;
	track->size++;
}

static void var_value(struct smf_track *track, unsigned long val) {
	unsigned long buf;

	buf=val&0x7F;
	while(val>>=7) {
		buf <<= 8;
		buf |= 0x80;
		buf += (val & 0x7F);
	}
	while(1) {
		add_byte(track,(int)buf);
		if(buf&0x80) buf>>=8;
		else break;
	}
}
*/
/*static void delta_time(struct smf_track *track, const snd_seq_event_t *ev)
{
	snd_seq_real_time_t
		diff,
		*last_t = &track->last_time;

	const snd_seq_real_time_t *ev_t = &ev->time.time;
	double qn_t;
	
	if (ev_t->tv_nsec < last_t->tv_nsec) {
		diff.tv_nsec = 1000000000L - (last_t->tv_nsec - ev_t->tv_nsec);
		diff.tv_sec = ev_t->tv_sec - last_t->tv_sec - 1;
	} else {
		diff.tv_nsec = ev_t->tv_nsec - last_t->tv_nsec;
		diff.tv_sec = ev_t->tv_sec - last_t->tv_sec;
	}
	qn_t = ((double)tv2ms(&diff)/mspqn);
	var_value(track, nearbyintf(ticks * qn_t)); //WHY do I need round() here?!
	*last_t = *ev_t;
}
*/
static int put_var_value(FILE *file, unsigned long val) {
	unsigned long buf;
        int n = 0;

	buf=val&0x7F;
	while(val>>=7) {
		buf <<= 8;
		buf |= 0x80;
		buf += (val & 0x7F);
	}
	while(1) {
		fputc((int)buf,file);
                n++;
		if(buf&0x80) buf>>=8;
		else break;
	}
        return n;
}

static int export_midi(MidiBus *b, char *filename, int tpqn, double spqn)
{
    FILE *file = fopen(filename,"wb");
/*    jack_nframes_t time;
    unsigned char data[4];
    int size;
*/
    int i,j,track_bytes=0;
    long last_tick = 0;
    long len_fp;
    int uspqn = spqn*1000000.0;
    
//    for(i=0;i<b->n_events;i++) {
//        track_bytes += b->events[i].size;
//    }
//    g_print("MIDI track has %d bytes\n",track_bytes);
        
    // header id and length
    fwrite("MThd\0\0\0\6", 1, 8, file);
    // type 0 or 1
    fputc(0, file);
    fputc(0, file); //set to one if more than one track
    // number of tracks
    fputc(0, file);
    fputc(1, file);
    // time division
//	if (smpte_timing)
//		time_division |= (0x100 - frames) << 8;
    fputc(tpqn >> 8, file);
    fputc(tpqn & 0xff, file);

//	for (i = 0; i < num_tracks; ++i) {

    // track id
    fwrite("MTrk", 1, 4, file);
    len_fp = ftell(file);
    for(i=0;i<4;i++) fputc(0,file); //make room for track data length

    // tempo
    fputc(0, file);
    fputc(0xFF, file);
    fputc(0x51, file);
    fputc(0x03, file);
    fputc((uspqn >> 16) & 0xff, file);
    fputc((uspqn >> 8) & 0xff, file);
    fputc(uspqn & 0xff, file);
    track_bytes += 7;
    g_print("MIDI tempo: %g BPM\n",60000000.0/(double)uspqn);
    
    for(i=0;i<b->n_events;i++) {
        MidiEvent *ev = &b->events[i];
        double t = (double)ev->time/(double)samplerate;
        long tick = ((double)(t*tpqn))/spqn;
        long dt = tick - last_tick;
        last_tick = tick;
        track_bytes += put_var_value(file,dt);
//        g_print("t: %g, tick: %d, dt: %ld, bytes: %d\n",t,tick,dt,ev->size);
        track_bytes += fwrite(ev->data,1,ev->size,file);
    }
  
    fputc(0x00,file); //delta-time, straight after last event
    fputc(0xff,file); //end-of-track event
    fputc(0x2f,file);
    fputc(0x00,file);
    track_bytes += 4;

    g_print("MIDI track had %d bytes\n",track_bytes);
    // patch data length, must include variable-length deltatimes
    fseek(file,len_fp,SEEK_SET);
    fputc((track_bytes >> 24) & 0xff, file);
    fputc((track_bytes >> 16) & 0xff, file);
    fputc((track_bytes >> 8) & 0xff, file);
    fputc(track_bytes & 0xff, file);

    fclose(file);
    
    g_print("Wrote %d events to file: %s\n",b->n_events,filename);
}

#define EXPORT_CHUNK 512
int export_audio(AudioBus *b, char *filename, int format, int norm, naRef cb) {
    int n,i;
    SNDFILE *isf, *osf;
    SF_INFO oinfo;
    float buffer[EXPORT_CHUNK*b->nports];
    int proc_cnt = 0;
    double pos = 0;

// Add format and normalization choice..
//    oinfo.format = SF_FORMAT_PCM_16 | SF_FORMAT_WAV;
    oinfo.format = format;
//    oinfo.format = SF_FORMAT_FLOAT | SF_FORMAT_WAV;
    oinfo.channels = b->nports;
    oinfo.samplerate = samplerate/b->sr_div;
   
    if((osf = sf_open(filename,SFM_WRITE,&oinfo))==0) {
        g_printerr("Could not open soundfile %s for writing: %s\n",filename,sf_strerror(osf));
        return 0;
    }
//    g_print("osf norm was %d\n",sf_command(osf, SFC_SET_NORM_FLOAT, NULL, SF_TRUE));

    naContext ctx = naNewContext();
                   
//    for(n=0;n<b->nregions;n++) {
        double max;
        sf_count_t read_frames;
//        Region *r = &b->region[n];
//        isf = sf_open(r->file,SFM_READ,&(r->info));
        isf = sf_open(b->file,SFM_READ,&(b->info));
        
        sf_command(isf, SFC_CALC_NORM_SIGNAL_MAX, &max, sizeof (max));
        //FIXME: normalization should be calculated over all regions,
        //and region->amp should be used.
        g_print("signal_max: %g\n",max);        
//        sf_command(isf, SFC_SET_NORM_FLOAT, NULL, SF_TRUE);
        if(max==0) max=1;
        
        while(1) {
            //FIXME:
            //- handle case where infile and outfile has different
            //  number of channels?
            read_frames = sf_readf_float(isf,buffer,EXPORT_CHUNK);
            pos += (double)read_frames/(double)oinfo.samplerate;
            if(norm) {
                for(i=0;i<EXPORT_CHUNK*oinfo.channels;i++)
                    buffer[i] /= max;
            }
            sf_writef_float(osf,buffer,EXPORT_CHUNK);
            if(proc_cnt==128) {
                naRef a = naNum(pos);
                naModUnlock();
                naCall(ctx,cb,1,&a,naNil(),naNil());
                naModLock();
                if(naGetError(ctx)) {
                    gchar *trace = get_stack_trace(ctx);
                    fprintf(stderr,"Error in export ui callback: %s",trace);
                    g_free(trace);
                }
                proc_cnt=0;
            } else
                proc_cnt++;
            if(read_frames<EXPORT_CHUNK) break;
        }
        sf_close(isf);
//    }
    sf_close(osf);
    naFreeContext(ctx);
    return 1;
}

void *disk_thread (void *arg)
{
//    jack_default_audio_sample_t buf[MAX_CHANS];

//    pthread_setcanceltype (PTHREAD_CANCEL_ASYNCHRONOUS, NULL); //?
    pthread_mutex_lock (&disk_thread_lock);

//    can_process = 1;

    while (1) {
        int do_locate = 0;
//        if(playing) {
//        pthread_mutex_lock (&busses_lock);

       
        if(locate_was_set) {
/*            GSList *l = busses;
            while(l) {
                AudioBus *b = (AudioBus*) l->data;
                l = g_slist_next(l);
                b->do_locate = 1;
                b->read_pos = locate_pos;
            }*/
            do_locate = 1;
            locate_was_set = 0;
//            read_pos = locate_pos;
            can_process = 0;
        }

        BUS_RLOCK();
        GSList *l = busses;
        while(l) {
            int i, n;
            AudioBus *b = (AudioBus*) l->data;
            l = g_slist_next(l);
            
/*            if(b->delete_me == 1) {
                printf("diskthread: bus delete_me was set, removing bus..\n");
                remove_bus(b);
                continue;
            }*/
            
/*            if(b->new_nregions) {
                free_regions(b);
                b->region=b->new_region;
                b->nregions=b->new_nregions;
                b->new_region=0;
                b->new_nregions=0;
//                printf("*** got %d new regions\n",b->nregions);
            }
*/            
            // Why not do this straight in the if(locate_was_set) above?
            // or check the global locate_was_set here
            if(do_locate) {
                b->silence = 1;
                sf_count_t pos = locate_pos/b->sr_div;
                if(sf_seek(b->sf, pos, SEEK_SET)>=0) b->silence = 0;
                else {
                    try_reopen(b);
                    if(sf_seek(b->sf, pos, SEEK_SET)>=0) b->silence = 0;
                }
                b->read_pos = pos;
//                jack_ringbuffer_reset(b->rb);
                memset(b->buf,0,MAX_CHANS);
            }
/*            if(do_locate) {
                b->curr_region = -1;
                b->silence = 1;
                for(i=0;i<b->nregions;i++) {
                    Region *r = &b->region[i];
                    if(r->start <= locate_pos) {
                        b->curr_region=i;
                    } else
                        break;
                }
                if(b->curr_region >= 0) {
                    Region *r = &b->region[b->curr_region];
                    sf_count_t pos = locate_pos - r->start;
                    if(sf_seek(r->sf, pos, SEEK_SET)>=0) b->silence = 0;
                    else {
                        try_reopen(b,r);
                        if(sf_seek(r->sf, pos, SEEK_SET)>=0) b->silence = 0;
                    }
                }
                b->read_pos = locate_pos; //TEST. or should it be the actual filepos?? no..
                jack_ringbuffer_reset(b->rb);
                memset(b->buf,0,32);
            }*/

//            jack_nframes_t avail = b->nports<1?0:jack_ringbuffer_write_space(b->rb[0])/sample_size;
            size_t avail_bytes = jack_ringbuffer_write_space(b->rb);
//??            buf[0] = 0;
//            if(b->nregions==0) {
//                printf("filling ringbuffer with %d bytes\n",avail_bytes);
//                jack_ringbuffer_write_advance(b->rb,avail_bytes);
 //               avail_bytes=0;
  //          }
            jack_nframes_t avail = avail_bytes/sample_size/b->nports;
//            if(playing) printf("*** rb available frames: %d\n",avail);
            while(avail) {
                int chans = 0;
                if(playing) {
/*                    if(b->curr_region+1 < b->nregions
                        && b->read_pos >= b->region[b->curr_region+1].start) {
                        Region *r = &b->region[++(b->curr_region)];
                        sf_seek(r->sf, b->read_pos - r->start, SEEK_SET);
                        b->silence = 0;
//                        printf("*** next region\n");
                    }*/
/*                    if(!b->silence && b->curr_region >= 0 && b->curr_region < b->nregions) {
                        Region *r = &b->region[b->curr_region];
                        chans = r->info.channels;*/
                    if(!b->silence) {
                        chans = b->info.channels;
                        
                        if(b->sr_div_count==0) {
                            sf_count_t read_frames = sf_readf_float(b->sf,b->buf,1);
                            // hackish trick: the file might have grown since
                            // playing started. Try to re-open it once.
                            if(read_frames==0) {
    //                            sf_close(r->sf);
    //                            r->sf = sf_open(r->file,SFM_READ,&(r->info));
    //                            sf_seek(r->sf, b->read_pos - r->start, SEEK_SET);
                                try_reopen(b);
//                                sf_seek(r->sf, b->read_pos - r->start, SEEK_SET);
                                sf_seek(b->sf, b->read_pos, SEEK_SET);
                                read_frames = sf_readf_float(b->sf,b->buf,1);
                                if(read_frames==0) b->silence=1;
                            }
                            b->read_pos++;
                            b->sr_div_count=b->sr_div-1;
                        } else {
                            b->sr_div_count--;
                        }
                    }
                }
//              else buf[0] = 0;
                if(chans>b->nports) chans=b->nports;
                for(i=0;i<chans;i++) {
                    jack_ringbuffer_write(b->rb,(void*)(&b->buf[i]),sample_size);
                }
//                if(chans) jack_ringbuffer_write(b->rb,(void*)buf,sample_size*chans);
                for(i=chans;i<b->nports;i++) {
                    jack_ringbuffer_write(b->rb,(void*)(&b->buf[0]),sample_size);
                }
                avail--;
//                avail -= b->nports;
//                b->read_pos++;
            }
/*            for(i=0;i<b->nports;i++) {
                while(jack_ringbuffer_write_space(b->rb[i]) > sample_size) {
                    float buf = playing?drand48():0;
                    jack_ringbuffer_write(b->rb[i],(void*)&buf,sample_size);
                }
            }
*/
        }
        BUS_UNLOCK();
       
//        read_pos += wrote/sample_size;
//        pthread_mutex_unlock (&busses_lock);
//        }
        // wait for the process thread to wake us up
//        printf("Waiting for data_ready\n");
//        fflush(stdout);
        can_process = 1;
    	pthread_cond_wait (&data_ready, &disk_thread_lock);
    }
   
    pthread_mutex_unlock (&disk_thread_lock);

//    fprintf(stderr,"diskthread terminated\n");    
   
    return 0;
}

static MidiBus *create_midibus(void) {
    MidiBus *b = malloc(sizeof(MidiBus));
    b->events = 0;
    b->n_events = 0;
    b->n_allocated = 0;
    b->port = 0;
    b->pos = 0;
    pthread_mutex_lock(&midi_lock);
    midi_busses = g_slist_prepend(midi_busses,(gpointer)b);
    pthread_mutex_unlock(&midi_lock);
    return b;
}

static OSCBus *create_oscbus(void) {
#ifndef LIBLO_FOUND
    g_printerr("Warning: AlgoScore was not compiled with OSC support\n");
#endif
    OSCBus *b = malloc(sizeof(OSCBus));
    b->events = 0;
    b->n_events = 0;
    b->n_allocated = 0;
    b->addr = lo_address_new(NULL,"7770");
    b->pos = 0;
    pthread_mutex_lock(&osc_lock);
    osc_busses = g_slist_prepend(osc_busses,(gpointer)b);
    pthread_mutex_unlock(&osc_lock);
    return b;
}

static AudioBus *create_bus(void) {
    AudioBus *b = (AudioBus *) malloc(sizeof(AudioBus));
//    b->nregions = 0;
//    b->new_nregions = 0;
//    b->region = 0;
//    b->new_region = 0;
//    b->curr_region = 0;
    b->nports = 0;
    b->port = 0;
//    b->rb = 0;
//    b->delete_me = 0;
//    b->do_locate = 0;
    b->amp = 1.0;
    b->read_pos = 0;
//    b->export_file = 0;
    b->sr_div = 1;
    b->sr_div_count = 0;
    
    b->rb = jack_ringbuffer_create (sample_size * RB_SIZE);
    memset(b->rb->buf, 0, b->rb->size);

    b->file = 0;
    b->sf = 0;
    memset(b->buf, 0, MAX_CHANS);

    BUS_WLOCK();
//    pthread_mutex_lock(&disk_thread_lock);
    busses = g_slist_prepend(busses,(gpointer)b);
//    pthread_mutex_unlock(&disk_thread_lock);
    BUS_UNLOCK();
    return b;
}

//static void free_bus(AudioBus *b) {
//    int i;
//    busses = g_slist_remove(busses,(gpointer)b);
//    free(b);
//}

typedef struct { AudioBus *bus; } busGhost;
static void busGhostDestroy(busGhost *g)
{
//    free_bus(g->bus);
    BUS_WLOCK();
//    pthread_mutex_lock(&disk_thread_lock);
//    pthread_mutex_lock(&process_lock);
/*    if(g->bus->delete_me==2) {
        printf("freeing bus directly\n");
        free(g->bus);
    } else {
        printf("setting bus delete_me = 3\n");
        g->bus->delete_me=3;
    }*/
//    remove_bus(g->bus);
//    printf("ghostDestroy: freeing bus\n");
    free(g->bus);
//    pthread_mutex_unlock(&process_lock);
//    pthread_mutex_unlock(&disk_thread_lock);
    BUS_UNLOCK();
    free(g);
}
static naGhostType busGhostType = {
    (void(*)(void*))busGhostDestroy, "AudioBus"
};
naRef newBusGhost(naContext ctx, AudioBus *bus)
{
    busGhost *g = malloc(sizeof(busGhost));
    g->bus = bus;
    return naNewGhost(ctx,&busGhostType,g);
}
static AudioBus *ghost2bus(naRef r)
{
    if(naGhost_type(r) != &busGhostType)
        return 0;
    return ((busGhost*)naGhost_ptr(r))->bus;
}

typedef struct { MidiBus *bus; } midiBusGhost;
static void midiBusGhostDestroy(midiBusGhost *g)
{
    free(g->bus);
    free(g);
}
static naGhostType midiBusGhostType = {
    (void(*)(void*))midiBusGhostDestroy, "MidiBus"
};
naRef newMidiBusGhost(naContext ctx, MidiBus *bus)
{
    midiBusGhost *g = malloc(sizeof(midiBusGhost));
    g->bus = bus;
    return naNewGhost(ctx,&midiBusGhostType,g);
}
static MidiBus *ghost2midibus(naRef r)
{
    if(naGhost_type(r) != &midiBusGhostType)
        return 0;
    return ((midiBusGhost*)naGhost_ptr(r))->bus;
}

typedef struct { OSCBus *bus; } oscBusGhost;
static void oscBusGhostDestroy(oscBusGhost *g)
{
    free(g->bus);
    free(g);
}
static naGhostType oscBusGhostType = {
    (void(*)(void*))oscBusGhostDestroy, "OSCBus"
};
naRef newOSCBusGhost(naContext ctx, OSCBus *bus)
{
    oscBusGhost *g = malloc(sizeof(oscBusGhost));
    g->bus = bus;
    return naNewGhost(ctx,&oscBusGhostType,g);
}
static OSCBus *ghost2oscbus(naRef r)
{
    if(naGhost_type(r) != &oscBusGhostType)
        return 0;
    return ((oscBusGhost*)naGhost_ptr(r))->bus;
}
static OSCBus *arg_oscbus(naContext c, int argc, naRef *a, int n, const char *f)
{
    OSCBus *b = ghost2oscbus(check_arg(c,n,argc,a,f));
    if(!b) naRuntimeError(c,"Arg %d to %s() not an OSCBus",n+1,f);
    return b;
}

static AudioBus *arg_audiobus(naContext c, int argc, naRef *a, int n, const char *f)
{
    AudioBus *b = ghost2bus(check_arg(c,n,argc,a,f));
    if(!b) naRuntimeError(c,"Arg %d to %s() not an AudioBus",n+1,f);
    return b;
}
static MidiBus *arg_midibus(naContext c, int argc, naRef *a, int n, const char *f)
{
    MidiBus *b = ghost2midibus(check_arg(c,n,argc,a,f));
    if(!b) naRuntimeError(c,"Arg %d to %s() not a MidiBus",n+1,f);
    return b;
}

#define AUDIOBUSARG(n) arg_audiobus(ctx, argc, args, (n), (__FUNCTION__+2))
#define MIDIBUSARG(n) arg_midibus(ctx, argc, args, (n), (__FUNCTION__+2))
#define OSCBUSARG(n) arg_oscbus(ctx, argc, args, (n), (__FUNCTION__+2))

///////////////////////////////////////////////////////////////////////
static naRef f_create_bus(naContext ctx, naRef me, int argc, naRef *args) {
    return newBusGhost(ctx,create_bus());
}

static naRef f_create_midibus(naContext ctx, naRef me, int argc, naRef *args) {
    return newMidiBusGhost(ctx,create_midibus());
}

static naRef f_create_oscbus(naContext ctx, naRef me, int argc, naRef *args) {
    return newOSCBusGhost(ctx,create_oscbus());
}

/*
static void _print_busses(gpointer data, gpointer user_data) {
    AudioBus *b = (AudioBus*)data;
//    printf("bus: export_file=%s nports=%d\n",b->export_file,b->nports);
    printf("bus: nports=%d\n",b->nports);
}

static naRef f_list_busses(naContext ctx, naRef me, int argc, naRef *args) {
    g_slist_foreach(busses, _print_busses, 0);
    return naNil();
}
*/
static naRef f_remove_bus(naContext ctx, naRef me, int argc, naRef *args) {
    AudioBus *b = ghost2bus(args[0]);
    if(b) {
//        b->delete_me = 1;
        remove_bus(b);
    } else {
        MidiBus *b = ghost2midibus(args[0]);
        if(b) {
            remove_midibus(b);
        } else {
            OSCBus *b = ghost2oscbus(args[0]);
            if(!b) naRuntimeError(ctx,"arg to remove_bus() was not a bus");
            remove_oscbus(b);
        }
    }
    return naNil();
}

static naRef f_set_midiport(naContext ctx, naRef me, int argc, naRef *args) {
    MidiBus *b = MIDIBUSARG(0); //ghost2midibus(args[0]);
    char *prefix = naStr_data(STRARG(1)); //naStr_data(args[1]);
    if(!client) return naNil();
#ifndef JACK_NO_MIDI
    pthread_mutex_lock(&midi_lock);
    if(b->port) {
        g_print("unregistering jack midiport %s\n", jack_port_name(b->port));
        jack_port_unregister(client,b->port);
    }
    b->port = jack_port_register(client, prefix, JACK_DEFAULT_MIDI_TYPE, JackPortIsOutput|JackPortIsTerminal, 0);
    g_print("registered jack midiport %s\n", jack_port_name(b->port));
    pthread_mutex_unlock(&midi_lock);
#endif
    return naNil();
}

static naRef f_setup_ports(naContext ctx, naRef me, int argc, naRef *args) {
    int i;
    AudioBus *b = AUDIOBUSARG(0);
    char *prefix = naStr_data(STRARG(1));
    int n = NUMARG(2);
    int auto_con = argc>3?NUMARG(3):1;

    BUS_WLOCK();    
    if(client) {
        char *name = g_strconcat(prefix,"_XX",NULL);
        int idx = strlen(prefix)+1;

        if(n!=b->nports) {
            i=b->nports;
            while(i>n) {
                i--;
                g_print("unregistering jack port %s\n", jack_port_name(b->port[i]));
                jack_port_unregister(client,b->port[i]);
            }
            b->port = (jack_port_t **) realloc(b->port, n*sizeof(jack_port_t*));
        }

        for(i=0;i<n;i++) {
            snprintf(&name[idx],3,"%02d",i+1);
            char play_name[] = "system:playback_X";
            play_name[16] = '1' + i;
            if(i>=b->nports) {
                b->port[i] = jack_port_register(client, name, JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput|JackPortIsTerminal, 0);
                g_print("registered jack port %s\n", jack_port_name(b->port[i]));
                if(auto_con) jack_connect (client, jack_port_name(b->port[i]), play_name);
            } else if(strcmp(jack_port_short_name(b->port[i]),name)!=0) {
                g_print("renaming jack port %s -> %s\n", jack_port_short_name(b->port[i]),name);
// jack_port_set_name() seems to cause crashes on older versions of jack?
#ifdef JACK_STABLE_MIDI
                jack_port_set_name(b->port[i], name);
#else
                jack_port_unregister(client, b->port[i]);
                b->port[i] = jack_port_register(client, name, JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput|JackPortIsTerminal, 0);
                if(auto_con) jack_connect (client, jack_port_name(b->port[i]), play_name);
#endif
            }
        }
        free(name);
        b->nports = n;
    }
    BUS_UNLOCK();
    return naNil();
}

static naRef f_set_amp(naContext ctx, naRef me, int argc, naRef *args) {
    AudioBus *b = AUDIOBUSARG(0);
    b->amp = NUMARG(1);
    return naNil();
}

/*
static naRef f_set_regions(naContext ctx, naRef me, int argc, naRef *args) {
    AudioBus *b = AUDIOBUSARG(0); //ghost2bus(args[0]);
    naRef regs = VECARG(1);//argc>1?args[1]:naNil();
    int i, n;
    Region *new_region;
    
//    if(!naIsVector(regs))
//        naRuntimeError(ctx,"arg 2 to set_regions() not a vector");
    
    n = naVec_size(regs);
    new_region = (Region*) malloc(sizeof(Region)*n);
    
    for(i=0;i<n;i++) {
        naRef v = naVec_get(regs,i);
        if(!naIsVector(v))
            naRuntimeError(ctx,"element %d of arg 2 to set_regions() is not a vector",i);
        Region *r = &new_region[i];
        r->file = strdup(naStr_data(naVec_get(v,0)));
        r->start = naNumValue(naVec_get(v,1)).num * samplerate;
        if(naVec_size(v)>2) { //RAW float data needs channel spec
            //but what should happen if number of channels doesn't match
            //the bus?
            r->info.channels = naNumValue(naVec_get(v,2)).num;
            r->info.samplerate = samplerate/b->sr_div; //fix this when we have SRC
            r->info.format = SF_FORMAT_RAW|SF_FORMAT_FLOAT;
        } else
            r->info.format = 0;
        r->sf = sf_open(r->file,SFM_READ,&(r->info));
        if(r->sf==0) {
            g_printerr("Could not open soundfile %s: %s\n",r->file,sf_strerror(r->sf));
        } else {
            g_print("added region: '%s' %d chnls %d Hz\n",r->file,r->info.channels,r->info.samplerate);
        }
    }

    BUS_WLOCK();    
//    pthread_mutex_lock(&disk_thread_lock);
//    pthread_mutex_lock(&process_lock);
    //FIXME: we should free any previous new_region!
    b->new_region = new_region;
    b->new_nregions = n;
//    b->do_locate = 1;
//    pthread_mutex_unlock(&process_lock);
//    pthread_mutex_unlock(&disk_thread_lock);
    BUS_UNLOCK();
    return naNil();
}
*/

static naRef f_set_file(naContext ctx, naRef me, int argc, naRef *args) {
    AudioBus *b = AUDIOBUSARG(0);
    naRef v = VECARG(1);

    BUS_WLOCK();
    if(b->file) g_free(b->file);
    b->file = strdup(naStr_data(naVec_get(v,0)));
//        r->start = naNumValue(naVec_get(v,1)).num * samplerate;
    if(naVec_size(v)>1) { //RAW float data needs channel spec
        //but what should happen if number of channels doesn't match
        //the bus?
        b->info.channels = naNumValue(naVec_get(v,1)).num;
        b->info.samplerate = samplerate/b->sr_div; //fix this when we have SRC
        b->info.format = SF_FORMAT_RAW|SF_FORMAT_FLOAT;
    } else
        b->info.format = 0;
    if(b->sf) sf_close(b->sf);
    b->sf = sf_open(b->file,SFM_READ,&(b->info));
    if(b->sf==0) {
        g_printerr("Could not open soundfile %s: %s\n",b->file,sf_strerror(b->sf));
    } else {
        g_print("Bus file: '%s' %d chnls %d Hz\n",b->file,b->info.channels,b->info.samplerate);
    }
    BUS_UNLOCK();
    return naNil();
}


/*static naRef f_set_export_file(naContext ctx, naRef me, int argc, naRef *args) {
    AudioBus *b = ghost2bus(args[0]);
    free(b->export_file);
    b->export_file = strdup(naStr_data(args[1]));
    return naNil();
}
*/

static gboolean notify_jack_shutdown(gpointer data)
{
    g_printerr("JACK server shutdown\n");
    return FALSE;
}

void jack_shutdown(void *arg)
{
//    can_process = 0;
    playing = 0;
//    jack_deactivate(client);
//    jack_client_close(client);
    old_client = client;
    client = 0;

    g_idle_add(notify_jack_shutdown,NULL);
}
/*
#ifdef LIBLO_FOUND
void *osc_thread(void* arg) {
    struct timespec ts;
    ts.tv_sec = 0;
    ts.tv_nsec = OSC_TICK_MS*1000000;
    while(1) {
        if(playing && pthread_mutex_trylock (&osc_lock) == 0) {
            GSList *l = osc_busses;
            while(l) {
                OSCBus *b = (OSCBus*) l->data;
                l = g_slist_next(l);
                OSCEvent *ev = &b->events[b->pos];
                while(ev->time <= osc_ticks && b->pos<b->n_events) {
                    lo_send_message(b->addr,ev->path,ev->msg);
                    b->pos++;
                    ev++;
                }
            }
            pthread_mutex_unlock (&osc_lock);
        }
        osc_ticks++;
        nanosleep(&ts,NULL);
    }
}
#endif
*/


#define NS_PER_SEC (long)1000000000

//struct timespec start_time;

void timespec_subtract(struct timespec *start, struct timespec *end, struct timespec *result)
{
    if (end->tv_nsec < start->tv_nsec) {
        result->tv_sec  = end->tv_sec - start->tv_sec - 1;
        result->tv_nsec = (NS_PER_SEC - start->tv_nsec) + end->tv_nsec;
    } else {
        result->tv_sec  = end->tv_sec - start->tv_sec;
        result->tv_nsec = end->tv_nsec - start->tv_nsec;
    }
}

#ifdef LIBLO_FOUND
void *osc_thread(void* arg) {
    struct timespec start, next;
    double nt = -1.0;
    pthread_mutex_lock (&osc_lock);
    while(1) {
        int err;
        if(nt > 0.0) {
//            printf("OSC: waiting %g ms for next event\n",nt*1000);
            next.tv_sec += (long)nt;
            next.tv_nsec += (long)(nt*NS_PER_SEC)%NS_PER_SEC;

            if(next.tv_nsec >= NS_PER_SEC) {
                next.tv_sec += next.tv_nsec / NS_PER_SEC;
                next.tv_nsec = next.tv_nsec % NS_PER_SEC;
            }

            err = pthread_cond_timedwait(&osc_start, &osc_lock, &next);
        } else {
//            printf("OSC: waiting for start signal\n");
            err = pthread_cond_wait(&osc_start, &osc_lock);
        }
        if(err == 0) {
            clock_gettime(CLOCK_REALTIME,&start);
            next = start;
        }
        nt = -1.0;

//        if(playing) {
//        if(jack_transport_query(client,NULL)==JackTransportRolling) {
        if(playing_osc) {
            struct timespec dt, now;
            double t;
            GSList *l = osc_busses;
            clock_gettime(CLOCK_REALTIME,&now);
            timespec_subtract(&start,&now,&dt);
            t = dt.tv_sec + (double)dt.tv_nsec/NS_PER_SEC + locate_pos_sec;
//            printf("t = %g ms\n",t*1000);
            while(l) {
                OSCBus *b = (OSCBus*) l->data;
                l = g_slist_next(l);
                OSCEvent *ev = &b->events[b->pos];
                while(ev->time <= t+0.0005 && b->pos < b->n_events) {
//                    printf("Late by %g ms\n",(t-ev->time)*1000);
                    lo_send_message(b->addr,ev->path,ev->msg);
                    b->pos++;
                    ev++;
                }
                if(b->pos < b->n_events && (nt < 0.0 || ev->time-t < nt))
                    nt=ev->time-t;
            }
        }
    }
    pthread_mutex_unlock (&osc_lock);
}
#endif

static naRef f_init(naContext ctx, naRef me, int argc, naRef *args) {
    struct sched_param proc_param;
    int proc_policy;

//    if(old_client) {
//        jack_client_close(old_client);
//        old_client = 0;
//    }

    if(client) {
        g_print("jack client already created\n");
        return naNum(2);
    }
#ifdef JACK_NO_MIDI
    if ((client = jack_client_new("algoscore")) == 0)
#else
    if ((client = jack_client_open("algoscore",JackNoStartServer,NULL)) == NULL)
#endif
    {
        g_printerr("Could not connect to JACK, server not running?\n");
        return naNum(0);
    }
    g_print("Created jack client: %s\n",jack_get_client_name(client));

    jack_set_process_callback (client, process, 0);
    jack_on_shutdown (client, jack_shutdown, 0);
    
    samplerate = jack_get_sample_rate(client);
        
    if (jack_activate (client))
    {
        g_printerr("Could not activate JACK client\n");
        return naNum(0);
    }

//    pthread_create(&disk_thread_id, 0, disk_thread, 0);
    if(!disk_thread_id) {
        pthread_getschedparam(jack_client_thread_id(client),&proc_policy,&proc_param);
        jack_client_create_thread(client, &disk_thread_id, proc_param.sched_priority-1,
            1, disk_thread, 0);
//        fprintf(stderr,"disk thread ID: %d\n",disk_thread_id);
    }

//    setup_osc_sequencer();
#ifdef LIBLO_FOUND
    if(!osc_thread_id) {
#if (_POSIX_TIMERS > 0)
        struct timespec ts;
        clock_getres(CLOCK_REALTIME,&ts);
        g_print("clock resolution: %ds, %ldns\n",ts.tv_sec,ts.tv_nsec);
#endif
        pthread_create(&osc_thread_id,NULL,osc_thread,0);
//        jack_acquire_real_time_scheduling(osc_thread_id,proc_param.sched_priority-1);
    }
#endif
    
    return naNum(1);
}

static naRef f_get_play_pos(naContext ctx, naRef me, int argc, naRef *args) {
    return naNum((client && playing)?(double)play_pos/samplerate:-1);
}
/*static naRef f_get_read_pos(naContext ctx, naRef me, int argc, naRef *args) {
    return naNum(read_pos);
}*/

//void update_start_time(void) {
//    clock_gettime(CLOCK_REALTIME,&start_time);
//}

void do_locate(void) {
    play_pos = locate_pos;
//    locate_pos_sec = (double)locate_pos/samplerate;
    locate_was_set = 1;
//    can_process = 0;

    BUS_RLOCK();
    GSList *l = busses;
    while(l) {
        AudioBus *b = (AudioBus*) l->data;
        l = g_slist_next(l);
        jack_ringbuffer_reset(b->rb);
    }
    BUS_UNLOCK();
                
    pthread_mutex_lock(&midi_lock);
    l = midi_busses;
    while(l) {
        MidiBus *b = (MidiBus*) l->data;
        l = g_slist_next(l);
        b->pos = 0;
        while(b->pos < b->n_events && b->events[b->pos].time < locate_pos)
            b->pos++;
    }
    pthread_mutex_unlock(&midi_lock);
    
//    update_start_time();
        
#ifdef LIBLO_FOUND
    pthread_mutex_lock(&osc_lock);
    l = osc_busses;
    while(l) {
        OSCBus *b = (OSCBus*) l->data;
        l = g_slist_next(l);
        b->pos = 0;
        while(b->pos < b->n_events && b->events[b->pos].time < locate_pos_sec)
            b->pos++;
    }
    pthread_mutex_unlock(&osc_lock);
#endif

    if(client) jack_transport_locate(client,locate_pos);
}

static void signal_osc_thread(void) {
#ifdef LIBLO_FOUND
    pthread_mutex_lock(&osc_lock);
    pthread_cond_signal (&osc_start);
    pthread_mutex_unlock(&osc_lock);
#endif
}

static naRef f_set_play_state(naContext ctx, naRef me, int argc, naRef *args) {
    int new_play = NUMARG(0);//naNumValue(args[0]).num;
    if(!client) return naNil();
//    g_print("playing = %d\n",playing);
    if(new_play)
//        update_start_time();
        do_locate();
//    playing = new_play;
    if(new_play)
        jack_transport_start(client);
    else
        jack_transport_stop(client);
    playing_osc = new_play;
    signal_osc_thread();
    return naNil();
}

static naRef f_locate(naContext ctx, naRef me, int argc, naRef *args) {
    locate_pos_sec = NUMARG(0);
    locate_pos = locate_pos_sec*samplerate;
    do_locate();
    signal_osc_thread();
    return naNil();
}

static naRef f_clear_events(naContext ctx, naRef me, int argc, naRef *args) {
    MidiBus *b = MIDIBUSARG(0);//ghost2midibus(args[0]);
    pthread_mutex_lock(&midi_lock);
    free(b->events);
    b->events=0;
    b->n_allocated=0;
    b->n_events=0;
    pthread_mutex_unlock(&midi_lock);
    return naNil();
}

static naRef f_add_event(naContext ctx, naRef me, int argc, naRef *args) {
    MidiBus *b = MIDIBUSARG(0);//ghost2midibus(args[0]);
    MidiEvent *ev;
    double time = NUMARG(1);//naNumValue(args[1]).num;
    naRef data_in = STRARG(2);
    unsigned char *data = naStr_data(data_in);
    int i, sz = naStr_len(data_in);
    
    pthread_mutex_lock(&midi_lock);
    size_t n = b->n_events+1;
    if(n > b->n_allocated) {
        while(n > b->n_allocated)
            b->n_allocated += EV_ALLOC_CHUNK;
        b->events = (MidiEvent *) realloc(b->events, sizeof(MidiEvent) * b->n_allocated);
//        printf("allocated room for %d events\n",b->n_allocated);
    }
//    printf("setting event %d\n",b->n_events);
    ev = &b->events[b->n_events];
    b->n_events = n;

    ev->time = time * samplerate;
//    printf("storing event: t=%g ",time);
    for(i=0;i<sz && i<4;i++) {
        if(i>0) data[i] &= 0x7F;
        ev->data[i]=data[i];
//        printf(i==0?"%2X":" %3d",data[i]);
    }
//    printf("\n");
    ev->size = sz;
    pthread_mutex_unlock(&midi_lock);
    return naNil();
}

static naRef f_osc_clear_events(naContext ctx, naRef me, int argc, naRef *args) {
    OSCBus *b = OSCBUSARG(0);
    int i;
    pthread_mutex_lock(&osc_lock);
    for(i=0;i<b->n_events;i++) {
        OSCEvent *ev = &b->events[i];
        lo_message_free(ev->msg);
        free(ev->path);
    }
    free(b->events);
    b->events=0;
    b->n_allocated=0;
    b->n_events=0;
    pthread_mutex_unlock(&osc_lock);
    return naNil();
}

static naRef f_osc_add_event(naContext ctx, naRef me, int argc, naRef *args) {
#ifdef LIBLO_FOUND
    OSCBus *b = OSCBUSARG(0);
    OSCEvent *ev;
    double time = NUMARG(1);
    char *path = strdup(naStr_data(STRARG(2)));
    char *fmt = naStr_data(STRARG(3));
    char *p;
//    naRef data = VECARG(4);
    naRef data = argc>4?args[4]:naNil();
    int fmt_sz = strlen(fmt);
    int i;
    
    pthread_mutex_lock(&osc_lock);
    size_t n = b->n_events+1;
    if(n > b->n_allocated) {
        while(n > b->n_allocated)
            b->n_allocated += EV_ALLOC_CHUNK;
        b->events = (OSCEvent *) realloc(b->events, sizeof(OSCEvent) * b->n_allocated);
    }
    ev = &b->events[b->n_events];
    b->n_events = n;

    ev->time = time;
    ev->path = path;
    ev->msg = lo_message_new();

#define check_num() if(!naIsNum(naNumValue(val))) {\
    pthread_mutex_unlock(&osc_lock); \
    naRuntimeError(ctx,"OSC msg arg %d not number",i); }
#define check_str() if(!naIsString(naStringValue(ctx,val))) {\
    pthread_mutex_unlock(&osc_lock); \
    naRuntimeError(ctx,"OSC msg arg %d not string",i); }

    if(fmt_sz != 1 && fmt_sz!=naVec_size(data)) {
        pthread_mutex_unlock(&osc_lock);
        naRuntimeError(ctx,"OSC message format wants %d args, %d was given.",
            fmt_sz,naVec_size(data));
    }
    
    for(p=fmt,i=0;*p;p++,i++) {
        naRef val = fmt_sz==1?data:naVec_get(data,i);
        char *data_str = naStr_data(naStringValue(ctx,val));
        double data_num = naNumValue(val).num;
        switch(*p) {
            case LO_INT32:
                check_num();
                lo_message_add_int32(ev->msg, data_num);
            break;
            case LO_FLOAT:
                check_num();
                lo_message_add_float(ev->msg, data_num);
            break;
            case LO_DOUBLE:
                check_num();
                lo_message_add_double(ev->msg, data_num);
            break;
            case LO_STRING:
                check_str();
                lo_message_add_string(ev->msg, data_str);
            break;
            case LO_SYMBOL:
                check_str();
                lo_message_add_symbol(ev->msg, data_str);
            break;
            case LO_CHAR:
                check_num();
                lo_message_add_char(ev->msg, data_num);
            break;
            case LO_MIDI:
                if(naStr_len(val)>=4) {
                    uint8_t data_midi[4] = {data_str[0],data_str[1],data_str[2],data_str[3]};
                    lo_message_add_midi(ev->msg, data_midi);
                } else {
                    pthread_mutex_unlock(&osc_lock);
                    naRuntimeError(ctx,"OSC MIDI msg needs 4-byte string");
                }
            break;
            default: {
                pthread_mutex_unlock(&osc_lock);
                naRuntimeError(ctx,"Unknown OSC type tag '%c'",*p);
            }
        }
    }

    pthread_mutex_unlock(&osc_lock);
#endif
    return naNil();
}

static int cmp_double(double a, double b) {
    if(a<b) return -1;
    else if(a>b) return 1;
    else return 0;
}

static int ev_sort(const void *a, const void *b) {
    return cmp_double(((MidiEvent*)a)->time,((MidiEvent*)b)->time);
}
static int osc_ev_sort(const void *a, const void *b) {
    return cmp_double(((OSCEvent*)a)->time,((OSCEvent*)b)->time);
}

static naRef f_lsb14(naContext ctx, naRef me, int argc, naRef *args) {
    int val = NUMARG(0);
    return naNum(val&0x7F);
}
static naRef f_msb14(naContext ctx, naRef me, int argc, naRef *args) {
    int val = NUMARG(0);
    return naNum((val>>7)&0x7F);
}

static naRef f_sort_events(naContext ctx, naRef me, int argc, naRef *args) {
    MidiBus *b = MIDIBUSARG(0);
    pthread_mutex_lock(&midi_lock);
    qsort(b->events,b->n_events,sizeof(MidiEvent),ev_sort);
    pthread_mutex_unlock(&midi_lock);
    return naNil();
}

static naRef f_osc_sort_events(naContext ctx, naRef me, int argc, naRef *args) {
#ifdef LIBLO_FOUND
    OSCBus *b = OSCBUSARG(0);
    pthread_mutex_lock(&osc_lock);
    qsort(b->events,b->n_events,sizeof(OSCEvent),osc_ev_sort);

/*    int i;
    for(i=0;i<b->n_events;i++) {
       printf("%d: t = %g\n",i,b->events[i].time);
    }*/
    
    pthread_mutex_unlock(&osc_lock);
    return naNil();
#endif
}

static naRef f_osc_set_addr(naContext ctx, naRef me, int argc, naRef *args) {
#ifdef LIBLO_FOUND
    OSCBus *b = OSCBUSARG(0);
    pthread_mutex_lock(&osc_lock);
    lo_address_free(b->addr);
    b->addr = lo_address_new_from_url(naStr_data(STRARG(1)));
    pthread_mutex_unlock(&osc_lock);
    return naNil();
#endif
}

static naRef f_set_end(naContext ctx, naRef me, int argc, naRef *args) {
    end_pos = NUMARG(0) * samplerate;
    return naNil();
}

static naRef f_export_audio(naContext ctx, naRef me, int argc, naRef *args) {
    AudioBus *b = AUDIOBUSARG(0);
    char *f = naStr_data(STRARG(1));
    int format = NUMARG(2);
    int norm = NUMARG(3);
    naRef cb = FUNCARG(4);
    return naNum(export_audio(b,f,format,norm,cb));
}

static naRef f_set_sr_div(naContext ctx, naRef me, int argc, naRef *args) {
    AudioBus *b = AUDIOBUSARG(0);
    b->sr_div = NUMARG(1);
    return naNil();
}

static naRef f_get_sr(naContext ctx, naRef me, int argc, naRef *args) {
    return naNum(samplerate);
}

static naRef f_export_midi(naContext ctx, naRef me, int argc, naRef *args) {
    MidiBus *b = MIDIBUSARG(0);
    char *f = naStr_data(STRARG(1));
    int tpqn = NUMARG(2);
    double spqn = NUMARG(3);
    pthread_mutex_lock(&midi_lock);
    export_midi(b,f,tpqn,spqn);
    pthread_mutex_unlock(&midi_lock);
    return naNil();
}


#define F(x) { #x, f_##x }
static naCFuncItem funcs[] = {
    F(export_midi),
    F(create_bus),
    F(remove_bus),
    F(setup_ports),
    F(set_play_state),
    F(get_play_pos),
    F(get_sr),
//    F(set_regions),
    F(set_file),
    F(set_amp),
    F(set_sr_div),
    F(locate),
    F(init),
    F(create_midibus),
    F(clear_events),
    F(add_event),
    F(set_midiport),
    F(sort_events),
    F(set_end),
    F(lsb14),
    F(msb14),
    F(export_audio),
    F(create_oscbus),
    F(osc_clear_events),
    F(osc_add_event),
    F(osc_sort_events),
    F(osc_set_addr),
    { 0 }
};
#undef F

//#define E(x) naAddSym(ctx,ns,#x,naNum(SF_##x))
naRef naInit_playbus(naContext ctx)
{
    naRef ns = naGenLib(ctx, funcs);
    pthread_rwlock_init(&busses_lock,NULL);
    return ns;
}
//#undef E
