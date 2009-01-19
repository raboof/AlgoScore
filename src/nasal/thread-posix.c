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

#ifndef _WIN32

#include <pthread.h>
#include "code.h"

void* naNewLock()
{
    pthread_mutex_t* lock = naAlloc(sizeof(pthread_mutex_t));
    pthread_mutex_init(lock, 0);
    return lock;
}

void naFreeLock(void* lock)
{
    pthread_mutex_destroy(lock);
    naFree(lock);
}

void naLock(void* lock)
{
    pthread_mutex_lock((pthread_mutex_t*)lock);
}

void naUnlock(void* lock)
{
    pthread_mutex_unlock((pthread_mutex_t*)lock);
}

struct naSem {
    pthread_mutex_t lock;
    pthread_cond_t cvar;
    int count;
};

void* naNewSem()
{
    struct naSem* sem = naAlloc(sizeof(struct naSem));
    pthread_mutex_init(&sem->lock , 0);
    pthread_cond_init(&sem->cvar, 0);
    sem->count = 0;
    return sem;
}

void naFreeSem(void* p)
{
    struct naSem* sem = p;
    pthread_mutex_destroy(&sem->lock);
    pthread_cond_destroy(&sem->cvar);
    naFree(sem);
}

void naSemDown(void* sh)
{
    struct naSem* sem = (struct naSem*)sh;
    pthread_mutex_lock(&sem->lock);
    while(sem->count <= 0)
        pthread_cond_wait(&sem->cvar, &sem->lock);
    sem->count--;
    pthread_mutex_unlock(&sem->lock);
}

void naSemUp(void* sh, int count)
{
    struct naSem* sem = (struct naSem*)sh;
    pthread_mutex_lock(&sem->lock);
    sem->count += count;
    pthread_cond_broadcast(&sem->cvar);
    pthread_mutex_unlock(&sem->lock);
}

#endif

extern int GccWarningWorkaround_IsoCForbidsAnEmptySourceFile;
