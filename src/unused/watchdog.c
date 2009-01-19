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

#include <stdlib.h>
#include <unistd.h>
#include <signal.h>

#include "watchdog.h"

static int interval;

static struct sigaction handler;

void wd_restart(void) {
    sigset_t sigs;
    //We need to unblock the alarm signal since the handler
    //could (in this case, does) exit with a longjmp...
    //(If nasal used sigsetjmp() and siglongjmp() this wouldn't be needed?)
    sigemptyset(&sigs);
    sigaddset(&sigs,SIGALRM);
    sigprocmask(SIG_UNBLOCK,&sigs,NULL);
}

void wd_init(int sec,void(*cb)(void))
{
    sigset_t sigs;
    interval=sec;
    sigemptyset(&sigs);
    handler.sa_handler = (void(*)(int))cb;
    handler.sa_mask = sigs;
    handler.sa_flags = 0;
    handler.sa_restorer = NULL;
    sigaction(SIGALRM,&handler,NULL);
}

void wd_feed(void) {
    alarm(interval);
}
