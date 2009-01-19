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

#ifdef _WIN32

#include <windows.h>

#define MAX_SEM_COUNT 1024 // What are the tradeoffs with this value?

void* naNewLock()
{
    LPCRITICAL_SECTION lock = malloc(sizeof(CRITICAL_SECTION));
    InitializeCriticalSection(lock);
    return lock;
}

void  naLock(void* lock)   { EnterCriticalSection((LPCRITICAL_SECTION)lock); }
void  naUnlock(void* lock) { LeaveCriticalSection((LPCRITICAL_SECTION)lock); }
void naFreeLock(void* lock) { free(lock); }
void* naNewSem()           { return CreateSemaphore(0, 0, MAX_SEM_COUNT, 0); }
void  naSemDown(void* sem) { WaitForSingleObject((HANDLE)sem, INFINITE); }
void  naSemUp(void* sem, int count) { ReleaseSemaphore(sem, count, 0); }
void naFreeSem(void* sem) { ReleaseSemaphore(sem, 1, 0); }

#endif

extern int GccWarningWorkaround_IsoCForbidsAnEmptySourceFile;
