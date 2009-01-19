#ifndef HARDWARE_H
#define HARDWARE_H

#include "nasal.h"

#define MAX_PAC_SIZE 512
typedef struct {
    gint escape;
    gint get_channel;
    gint channel;
    guchar buf[MAX_PAC_SIZE];
    gint pos;
} StreamState;

naRef naInit_hardware(naContext ctx);

#endif
