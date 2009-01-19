# Copyright 2007, 2008, Jonatan Liljedahl
#
# This file is part of AlgoScore.
#
# AlgoScore is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# AlgoScore is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with AlgoScore.  If not, see <http://www.gnu.org/licenses/>.

# TODO:
# - value labels, margin
# - skip storing in vector, instead have an 'autoscale' button.
# - numentries for min/max, ymin/ymax
# - take func as string instead? then we can edit it in the GUI and
#   display them.. one problem is handling of the namespace.
#   there could be an 'init code' entry where one can do imports and
#   define functions..
#   But, the cmdline is a fast and nice interface too..
# - menu/list of plots, add/replace/delete. colorize. show all toggle?
# - merge with csound graphwin. allow table to be passed, with title.

import("gtk");
import("cairo");

var PlotWin={};
PlotWin.new = func(f,min=-1,max=1) {
    var o = {};
    o.parents = [PlotWin];
    o.min = min;
    o.max = max;
    o.fn = f;
    o.data = nil;
    o.w = gtk.Window("title","plot");
    o.w.connect("delete-event",func { o.w.hide(); o.w.destroy(); });
    o.d = gtk.DrawingArea();
    o.d.connect("expose-event",func(wid) {
        var cr = wid.cairo_create();
        cairo.set_source_rgb(cr,1,1,1);
        cairo.paint(cr);
        o.draw(cr);
        cairo.destroy(cr);
    });
    o.d.connect("configure-event",func(wid,ev) {
        o.width = ev.width;
        o.height = ev.height;
        o.plot();
    });
    o.w.add(o.d);

#    o.plot();
    o.w.show_all();
    return o;
}
PlotWin.plot = func(fn=nil) {
    if(fn!=nil) me.fn=fn;
    me.data = setsize([], me.width);
    var min = nil;
    var max = nil;
    for(gx=0;gx<me.width;gx+=1) {
        var x = gx/me.width*(me.max-me.min)+me.min;
        var y = me.fn(x);
        me.data[gx]=y;
        if(min==nil or y<min) min=y;
        if(max==nil or y>max) max=y;
    }
    if(min==max) { min-=1; max+=1; }
    me.ymin = min;
    me.ymax = max;
    me.d.queue_draw();
}
PlotWin.draw = func(cr) {
    if(me.data==nil) return;
    cairo.set_line_width(cr,1);
    
    cairo.set_source_rgb(cr,0.5,0.5,0.5);
    var x = int(me.min/(me.min-me.max)*me.width)+0.5;
    cairo.move_to(cr,x,0);
    cairo.rel_line_to(cr,0,me.height);
    var y = int(me.ymin/(me.ymin-me.ymax)*me.height)+0.5;
    cairo.move_to(cr,0,y);
    cairo.rel_line_to(cr,me.width,0);
    cairo.stroke(cr);
    
    cairo.set_source_rgb(cr,0,0,0);
    forindex(gx;me.data) {
        var y = me.data[gx];
        var gy = (y-me.ymax)/(me.ymin-me.ymax)*me.height;
        cairo.line_to(cr,gx,gy);
    }
    cairo.stroke(cr);
}

var new = PlotWin.new;
