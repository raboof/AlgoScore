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

#ifndef UTILS_H
#define UTILS_H

#include <glib.h>

//int checkError(naContext ctx, char *id);
//char *naTraceError(naContext ctx);
gchar *get_stack_trace(naContext ctx);

naRef check_arg(naContext ctx, int n, int ac, naRef *av, const char *fn);

naRef  arg_str  (naContext c, int argc, naRef *a, int n, const char *f);
double arg_num  (naContext c, int argc, naRef *a, int n, const char *f);
naRef  arg_func (naContext c, int argc, naRef *a, int n, const char *f);
naRef  arg_vec  (naContext c, int argc, naRef *a, int n, const char *f);

#define NUMARG(n) arg_num(ctx, argc, args, (n), (__FUNCTION__+2))
#define STRARG(n) arg_str(ctx, argc, args, (n), (__FUNCTION__+2))
#define FUNCARG(n) arg_func(ctx, argc, args, (n), (__FUNCTION__+2))
#define VECARG(n) arg_vec(ctx, argc, args, (n), (__FUNCTION__+2))

#endif
