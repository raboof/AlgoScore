/*
  Copyright 2006, 2007, 2008 Jonatan Liljedahl, Andrew Ross
 
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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <cairo/cairo.h>
#include <cairo/cairo-ps.h>
#include <cairo/cairo-pdf.h>
#include <cairo/cairo-svg.h>

#include "nasal.h"

#define NASTR(b) naStr_fromdata(naNewString(ctx), (char*)(b), strlen(b))

typedef struct { cairo_t *cr; } cairoGhost;
typedef struct { cairo_surface_t *s; } surfaceGhost;
typedef struct { cairo_pattern_t *pat; } patternGhost;

static void cairoGhostDestroy(cairoGhost *g)
{
    if(g->cr) cairo_destroy(g->cr);
    free(g);
}

static void surfaceGhostDestroy(surfaceGhost *g)
{
    if(g->s) cairo_surface_destroy(g->s);
    free(g);
}

static void patternGhostDestroy(patternGhost *g)
{
    cairo_pattern_destroy(g->pat);
    free(g);
}

static naGhostType cairoGhostType = { (void(*)(void*))cairoGhostDestroy,
                                      "cairo_context" };
static naGhostType surfaceGhostType = { (void(*)(void*))surfaceGhostDestroy,
                                        "cairo_surface" };
static naGhostType patternGhostType = { (void(*)(void*))patternGhostDestroy,
                                        "cairo_pattern" };

naRef naNewCairoGhost(naContext ctx, cairo_t *cr)
{
    cairoGhost *g = malloc(sizeof(cairoGhost));
    g->cr = cr;
    return naNewGhost(ctx,&cairoGhostType,g);
}

naRef naNewSurfaceGhost(naContext ctx, cairo_surface_t *s)
{
    surfaceGhost *g = malloc(sizeof(surfaceGhost));
    g->s = s;
    return naNewGhost(ctx,&surfaceGhostType,g);
}

naRef naNewPatternGhost(naContext ctx, cairo_pattern_t *pat)
{
    patternGhost *g = malloc(sizeof(patternGhost));
    g->pat = pat;
    return naNewGhost(ctx,&patternGhostType,g);
}

static cairo_t *ghost2cairo(naRef r)
{
    if(naGhost_type(r) != &cairoGhostType)
        return NULL;
    return ((cairoGhost*)naGhost_ptr(r))->cr;
}

static cairo_surface_t *ghost2surface(naRef r)
{
    if(naGhost_type(r) != &surfaceGhostType)
        return NULL;
    return ((surfaceGhost*)naGhost_ptr(r))->s;
}

static cairo_pattern_t *ghost2pattern(naRef r)
{
    if(naGhost_type(r) != &patternGhostType)
        return NULL;
    return ((patternGhost*)naGhost_ptr(r))->pat;
}

static naRef chkarg(naContext ctx, int n, int ac, naRef *av, const char* fn)
{
    if(n >= ac) naRuntimeError(ctx, "not enough arguments to cairo.%s", fn);
    return av[n];
}

static cairo_t *arg_cairo(naContext c, int argc, naRef *a, int n, const char *f)
{
    cairo_t *cr = ghost2cairo(chkarg(c,n,argc,a,f));
    if(!cr) naRuntimeError(c,"Arg %d to cairo.%s() not a context",n+1,f);
    return cr;
}

static cairo_surface_t *arg_surface(naContext c, int argc, naRef *a, int n, const char *f)
{
    cairo_surface_t *s = ghost2surface(chkarg(c,n,argc,a,f));
    if(!s) naRuntimeError(c,"Arg %d to cairo.%s() not a surface",n+1,f);
    return s;
}

static cairo_pattern_t *arg_pattern(naContext c, int argc, naRef *a, int n, const char *f)
{
    cairo_pattern_t *s = ghost2pattern(chkarg(c,n,argc,a,f));
    if(!s) naRuntimeError(c,"Arg %d to cairo.%s() not a pattern",n+1,f);
    return s;
}

static naRef arg_str(naContext c, int argc, naRef *a,int n, const char *f)
{
    naRef r = naStringValue(c,chkarg(c,n,argc,a,f));
    if(!naIsString(r)) naRuntimeError(c,"Arg %d to cairo.%s() not string",n+1,f);
    return r;
}

static double arg_num(naContext c, int argc, naRef *a,int n, const char *f)
{
    naRef r = naNumValue(chkarg(c,n,argc,a,f));
    if(!naIsNum(r)) naRuntimeError(c,"Arg %d to %s() not a num",n+1,f);
    return r.num;
}

#define NUMARG(n) arg_num(ctx, argc, args, (n), (__FUNCTION__+2))
#define STRARG(n) arg_str(ctx, argc, args, (n), (__FUNCTION__+2))
#define CAIROARG(n) arg_cairo(ctx, argc, args, (n), (__FUNCTION__+2))
#define SURFARG(n) arg_surface(ctx, argc, args, (n), (__FUNCTION__+2))
#define PATARG(n) arg_pattern(ctx, argc, args, (n), (__FUNCTION__+2))

#define CAIRO_0ARG(x) \
static naRef f_##x(naContext ctx, naRef me, int argc, naRef* args) { \
    cairo_##x(CAIROARG(0)); return naNil(); }

#define CAIRO_1ARG(x) \
static naRef f_##x(naContext ctx, naRef me, int argc, naRef* args) { \
    double a = NUMARG(1); \
    cairo_##x(CAIROARG(0),a); return naNil(); }

#define CAIRO_2ARG(x) \
static naRef f_##x(naContext ctx, naRef me, int argc, naRef* args) { \
    double a = NUMARG(1); double b = NUMARG(2); \
    cairo_##x(CAIROARG(0),a,b); return naNil(); }

#define CAIRO_3ARG(x) \
static naRef f_##x(naContext ctx, naRef me, int argc, naRef* args) { \
    double a = NUMARG(1); double b = NUMARG(2); \
    double c = NUMARG(3); \
    cairo_##x(CAIROARG(0),a,b,c); return naNil(); }

#define CAIRO_4ARG(x) \
static naRef f_##x(naContext ctx, naRef me, int argc, naRef* args) { \
    double a = NUMARG(1); double b = NUMARG(2); \
    double c = NUMARG(3); double d = NUMARG(4); \
    cairo_##x(CAIROARG(0),a,b,c,d); return naNil(); }

#define CAIRO_5ARG(x) \
static naRef f_##x(naContext ctx, naRef me, int argc, naRef* args) { \
    double a = NUMARG(1); double b = NUMARG(2); \
    double c = NUMARG(3); double d = NUMARG(4); \
    double e = NUMARG(5); \
    cairo_##x(CAIROARG(0),a,b,c,d,e); return naNil(); }

#define CAIRO_6ARG(x) \
static naRef f_##x(naContext ctx, naRef me, int argc, naRef* args) { \
    double a = NUMARG(1); double b = NUMARG(2); \
    double c = NUMARG(3); double d = NUMARG(4); \
    double e = NUMARG(5); double f = NUMARG(6); \
    cairo_##x(CAIROARG(0),a,b,c,d,e,f); return naNil(); }


/*double get_time(void) {
    struct timeval tod;
    gettimeofday(&tod,0);
    return (tod.tv_sec*1000.0 + tod.tv_usec * (1.0/1000.0));
}
static naRef f_stroke_preserve(naContext ctx, naRef me, int argc, naRef* args) {
    double t = get_time();
    char *fn = "xyz"; cairo_t *cr = arg_cairo(ctx,argc,args,0,fn);
    cairo_stroke_preserve(cr);
    printf("Stroke: %.5f ms",get_time()-t);
    return naNil();
}
*/
CAIRO_0ARG(stroke)
CAIRO_0ARG(stroke_preserve)
CAIRO_0ARG(fill)
CAIRO_0ARG(fill_preserve)
CAIRO_0ARG(show_page)
CAIRO_0ARG(copy_page)
CAIRO_0ARG(save)
CAIRO_0ARG(restore)
CAIRO_0ARG(new_path)
CAIRO_0ARG(close_path)
CAIRO_0ARG(clip)
CAIRO_0ARG(paint)
CAIRO_0ARG(new_sub_path)

CAIRO_1ARG(set_line_width)
CAIRO_1ARG(set_font_size)
CAIRO_1ARG(set_line_cap)
CAIRO_1ARG(set_line_join)
CAIRO_1ARG(set_antialias)
CAIRO_1ARG(set_operator)
CAIRO_1ARG(rotate)
CAIRO_1ARG(paint_with_alpha)

CAIRO_2ARG(move_to)
CAIRO_2ARG(line_to)
CAIRO_2ARG(rel_move_to)
CAIRO_2ARG(rel_line_to)
CAIRO_2ARG(scale)
CAIRO_2ARG(translate)

CAIRO_3ARG(set_source_rgb)

CAIRO_4ARG(set_source_rgba)
CAIRO_4ARG(rectangle)

CAIRO_5ARG(arc)

CAIRO_6ARG(curve_to)
CAIRO_6ARG(rel_curve_to)

#undef CAIRO_0ARG
#undef CAIRO_1ARG
#undef CAIRO_2ARG
#undef CAIRO_3ARG
#undef CAIRO_4ARG
#undef CAIRO_5ARG
#undef CAIRO_6ARG

static naRef f_create(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_surface_t *s = arg_surface(ctx,argc,args,0,"cairo_create");
    return naNewCairoGhost(ctx,cairo_create(s));
}

static naRef f_get_target(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_t *cr = arg_cairo(ctx,argc,args,0,"cairo_get_target");
    cairo_surface_t *s = cairo_get_target(cr);
    cairo_surface_reference(s);
    return naNewSurfaceGhost(ctx,s);
}

static naRef f_surface_create_similar(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_surface_t *other = SURFARG(0);
    cairo_content_t content = (cairo_content_t)NUMARG(1);
    int width = (int)NUMARG(2);
    int height = (int)NUMARG(3);
    cairo_surface_t *s = cairo_surface_create_similar(other,content,width,height);
    return naNewSurfaceGhost(ctx,s);
}

static naRef f_ps_surface_create(naContext ctx, naRef me, int argc, naRef* args)
{
    const char *file = naStr_data(STRARG(0));
    double width = NUMARG(1);
    double height = NUMARG(2);
    cairo_surface_t *s = cairo_ps_surface_create(file,width,height);
    return naNewSurfaceGhost(ctx,s);
}

static naRef f_pdf_surface_create(naContext ctx, naRef me, int argc, naRef* args)
{
    const char *file = naStr_data(STRARG(0));
    double width = NUMARG(1);
    double height = NUMARG(2);
    cairo_surface_t *s = cairo_pdf_surface_create(file,width,height);
    return naNewSurfaceGhost(ctx,s);
}

static naRef f_svg_surface_create(naContext ctx, naRef me, int argc, naRef* args)
{
    const char *file = naStr_data(STRARG(0));
    double width = NUMARG(1);
    double height = NUMARG(2);
    cairo_surface_t *s = cairo_svg_surface_create(file,width,height);
    return naNewSurfaceGhost(ctx,s);
}

static naRef f_image_surface_create(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_format_t format = (cairo_format_t)NUMARG(0);
    int width = (int)NUMARG(1);
    int height = (int)NUMARG(2);
    cairo_surface_t *s = cairo_image_surface_create(format,width,height);
    return naNewSurfaceGhost(ctx,s);
}

static naRef f_surface_finish(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_surface_finish(SURFARG(0)); return naNil();
}

static naRef f_surface_flush(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_surface_flush(SURFARG(0)); return naNil();
}

static naRef f_surface_get_type(naContext ctx, naRef me, int argc, naRef* args)
{
    return naNum(cairo_surface_get_type(SURFARG(0)));
}

static naRef f_surface_set_fallback_resolution(naContext ctx, naRef me, int argc, naRef* args)
{
    double xdpi = NUMARG(1);
    double ydpi = NUMARG(2);
    cairo_surface_set_fallback_resolution(SURFARG(0),xdpi,ydpi);
    return naNil();
}

static naRef f_set_source_surface(naContext ctx, naRef me, int argc, naRef* args)
{
    double x = NUMARG(2);
    double y = NUMARG(3);
    cairo_set_source_surface(CAIROARG(0),SURFARG(1),x,y);
    return naNil();
}

static naRef f_show_text(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_show_text(CAIROARG(0),naStr_data(STRARG(1)));
    return naNil();
}

static naRef f_text_path(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_text_path(CAIROARG(0),naStr_data(STRARG(1)));
    return naNil();
}

static naRef f_select_font_face(naContext ctx, naRef me, int argc, naRef* args)
{
    const char *family = naStr_data(STRARG(1));
    cairo_font_slant_t slant = argc>2?NUMARG(2):CAIRO_FONT_SLANT_NORMAL;
    cairo_font_weight_t weight = argc>3?NUMARG(3):CAIRO_FONT_WEIGHT_NORMAL;
    cairo_select_font_face(CAIROARG(0),family,slant,weight);
    return naNil();
}

#define SET_NUM(a,b) naAddSym(ctx,h,(a),naNum(b))
static naRef f_text_extents(naContext ctx, naRef me, int argc, naRef* args)
{
    naRef h = naNewHash(ctx);
    const char *s = naStr_data(STRARG(1));
    cairo_text_extents_t te;
    cairo_text_extents(CAIROARG(0),s,&te);
    SET_NUM("x_bearing",te.x_bearing);
    SET_NUM("y_bearing",te.y_bearing);
    SET_NUM("x_advance",te.x_advance);
    SET_NUM("y_advance",te.y_advance);
    SET_NUM("width",te.width);
    SET_NUM("height",te.height);
    return h;
}

static naRef f_font_extents(naContext ctx, naRef me, int argc, naRef* args)
{
    naRef h = naNewHash(ctx);
    cairo_font_extents_t te;
    cairo_font_extents(CAIROARG(0),&te);
    SET_NUM("ascent",te.ascent);
    SET_NUM("descent",te.descent);
    SET_NUM("max_x_advance",te.max_x_advance);
    SET_NUM("max_y_advance",te.max_y_advance);
    SET_NUM("height",te.height);
    return h;
}

static naRef f_get_current_point(naContext ctx, naRef me, int argc, naRef* args)
{
    naRef v = naNewVector(ctx);
    double x,y;
    cairo_get_current_point(CAIROARG(0),&x,&y);
    naVec_append(v,naNum(x));
    naVec_append(v,naNum(y));
    return v;
}

static naRef f_stroke_extents(naContext ctx, naRef me, int argc, naRef* args)
{
    double x1,y1,x2,y2;
    naRef v = naNewVector(ctx);
    cairo_stroke_extents(CAIROARG(0),&x1,&y1,&x2,&y2);
    naVec_append(v,naNum(x1));
    naVec_append(v,naNum(y1));
    naVec_append(v,naNum(x2));
    naVec_append(v,naNum(y2));
    return v;
}

static naRef f_set_dash(naContext ctx, naRef me, int argc, naRef* args)
{
    naRef v = (argc>1 && naIsVector(args[1]))?args[1]:naNil();
    int i,sz = naVec_size(v);
    double *dashes = malloc(sizeof(double)*sz);
    double offset = argc>2?NUMARG(2):0;
    for(i=0;i<sz;i++)
        dashes[i] = naNumValue(naVec_get(v,i)).num;
    cairo_set_dash(CAIROARG(0),dashes,sz,offset);
    return naNil();
}

static naRef f_set_source(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_set_source(CAIROARG(0),PATARG(1));
    return naNil();
}

static naRef f_pattern_create_linear(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_pattern_t *pat = cairo_pattern_create_linear(NUMARG(0),NUMARG(1),NUMARG(2),NUMARG(3));
    return naNewPatternGhost(ctx,pat);
}

static naRef f_pattern_create_radial(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_pattern_t *pat = cairo_pattern_create_radial(
        NUMARG(0),NUMARG(1),NUMARG(2),NUMARG(3),NUMARG(4),NUMARG(5));
    return naNewPatternGhost(ctx,pat);
}

static naRef f_pattern_add_color_stop_rgb(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_pattern_add_color_stop_rgb(PATARG(0),
        NUMARG(1),NUMARG(2),NUMARG(3),NUMARG(4));
    return naNil();
}
static naRef f_pattern_add_color_stop_rgba(naContext ctx, naRef me, int argc, naRef* args)
{
    cairo_pattern_add_color_stop_rgba(PATARG(0),
        NUMARG(1),NUMARG(2),NUMARG(3),NUMARG(4),NUMARG(5));
    return naNil();
}

static naRef f_destroy(naContext ctx, naRef me, int argc, naRef* args)
{
    naRef r = args[0];
    cairoGhost* g;
    if(naIsNil(r)) return naNil();
    g=(cairoGhost*)naGhost_ptr(r);
    cairo_destroy(g->cr);
    g->cr = 0;
    return naNil();
}

static naRef f_surface_destroy(naContext ctx, naRef me, int argc, naRef* args)
{
    naRef r = args[0];
    surfaceGhost *g;
    if(naIsNil(r)) return naNil();
    g=(surfaceGhost*)naGhost_ptr(r);
    cairo_surface_destroy(g->s);
    g->s = 0;
    return naNil();
}

#define F(x) { #x, f_##x }
static naCFuncItem funcs[] = {
    F(destroy),
    F(surface_destroy),
    F(set_source),
    F(pattern_create_linear),
    F(pattern_create_radial),
    F(pattern_add_color_stop_rgb),
    F(pattern_add_color_stop_rgba),
    F(set_dash),
    F(set_antialias),
    F(rectangle),
    F(arc),
    F(close_path),
    F(new_path),
    F(save),
    F(restore),
    F(scale),
    F(rotate),
    F(set_font_size),
    F(set_line_width),
    F(set_line_cap),
    F(set_line_join),
    F(set_source_rgba),
    F(set_source_rgb),
    F(show_page),
    F(copy_page),
    F(stroke),
    F(stroke_preserve),
    F(fill),
    F(fill_preserve),
    F(clip),
    F(move_to),
    F(line_to),
    F(rel_move_to),
    F(rel_line_to),
    F(curve_to),
    F(rel_curve_to),
    F(show_text),
    F(translate),
    F(text_extents),
    F(font_extents),
    F(select_font_face),
    F(get_current_point),
    F(paint),
    F(paint_with_alpha),
    F(create),
    F(surface_create_similar),
    F(surface_set_fallback_resolution),
    F(surface_get_type),
    F(ps_surface_create),
    F(pdf_surface_create),
    F(svg_surface_create),
    F(image_surface_create),
    F(set_source_surface),
    F(get_target),
    F(set_operator),
    F(surface_finish),
    F(surface_flush),
    F(new_sub_path),
    F(stroke_extents),
    F(text_path),
    { 0 }
};
#undef F

#define E(x) naAddSym(ctx,ns,#x,naNum(CAIRO_##x))
naRef naInit_cairo(naContext ctx) {
    naRef ns = naGenLib(ctx,funcs);
    E(FONT_SLANT_NORMAL);
    E(FONT_SLANT_ITALIC);
    E(FONT_SLANT_OBLIQUE);
    E(FONT_WEIGHT_NORMAL);
    E(FONT_WEIGHT_BOLD);
    E(LINE_JOIN_MITER);
    E(LINE_JOIN_ROUND);
    E(LINE_JOIN_BEVEL);
    E(LINE_CAP_BUTT);
    E(LINE_CAP_ROUND);
    E(LINE_CAP_SQUARE);
    E(ANTIALIAS_DEFAULT);
    E(ANTIALIAS_NONE);
    E(ANTIALIAS_GRAY);
    E(ANTIALIAS_SUBPIXEL);
    E(CONTENT_COLOR);
    E(CONTENT_ALPHA);
    E(CONTENT_COLOR_ALPHA);
    E(OPERATOR_CLEAR);
    E(OPERATOR_SOURCE);
    E(OPERATOR_OVER);
    E(OPERATOR_IN);
    E(OPERATOR_OUT);
    E(OPERATOR_ATOP);
    E(OPERATOR_DEST);
    E(OPERATOR_DEST_OVER);
    E(OPERATOR_DEST_IN);
    E(OPERATOR_DEST_OUT);
    E(OPERATOR_DEST_ATOP);
    E(OPERATOR_XOR);
    E(OPERATOR_ADD);
    E(OPERATOR_SATURATE);
    E(FORMAT_ARGB32);
    E(FORMAT_RGB24);
    E(FORMAT_A8);
    E(FORMAT_A1);
    return ns;
}
#undef E
