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

import("algoscore");
import("cairo");
#import("gtk");
import("text");
import("palette");
import("math");

var ASSingle = {parents:[algoscore.ASObject]};
ASSingle.init = func(o) {
    algoscore.ASObject.init(o);
    o.parents = [ASSingle];
    o.length = 0;
    o.unused_regions = [];
    delete(o.properties,"length");
    return o;
}
#ASSingle.move_resize_done = func(m,r) {
#    if(r) me.length=0;
#    me.update();
#}
ASSingle.update_unused_regions = func nil;
ASSingle.get_alignments = func [0];
ASSingle.get_datasize = func 1;
ASSingle.get_event = func(outlet) [0,me.get_single(outlet)];
ASSingle.get_value = func(outlet) me.get_single(outlet);

var Comment = {name:"comment",parents:[text.TextLayer,ASSingle]};
Comment.description =
"<b>Place a text comment in the score.</b>\n\n"
"If <tt>marker in score</tt> property is set, a vertical gridline is"
" drawn at the left edge of the object.";
Comment.init = func(o) {
    ASSingle.init(o);
    text.TextLayer.init(o);
    o.parents = [Comment];
    o.timegrids = [0];
    o.add_obj_prop("marker in score","timegrids_enable");
    o.add_obj_prop("marker direction","timegrid_pos");
}

var CodeObj = {parents:[text.TextLayer,ASSingle]};
CodeObj.name = "code";
CodeObj.description =
"<b>Compile and evaluate nasal code.</b>\n\n"
"<b>Properties:</b>\n"
"- <tt>eval_once</tt> : if 0, the code will be evaluated"
" each time a receieving object asks for a value.\n"
"<b>Outlets:</b>\n"
"- <tt>value</tt> : outputs the returned value from the code.\n"
"- <tt>func</tt> : outputs the compiled function.\n\n"
"The code runs with the following variables available:\n"
"- <tt>math</tt> : the math library (sin, pow, mod, etc...)\n"
"- <tt>G_set(sym,val)</tt> : set global variable.\n"
"- <tt>G_get(sym)</tt> : get global variable.";
CodeObj.init = func(o) {
    ASSingle.init(o);
    text.TextLayer.init(o);
    o.parents = [CodeObj];
    o.code = nil;
    o.value = nil;
    o.eval_once = 1;
#    o.eval_init = 0;
    o.add_obj_prop("eval_once");
#    o.add_obj_prop("eval_init");
    o.new_outlet("value",0);
    o.new_outlet("func",0);
}
CodeObj.text_changed = func {
    me.code = compile(me.text);
#    if(me.eval_init) me.eval();
    # we should eval the code right away if delay_update
    if(me.score.delay_update) me.eval();
    me.remake_surface();
    me.update();
}
CodeObj.generate = func {
    me.code = compile(me.text);
    me.eval();
    0;
}
CodeObj.eval = func {
    var ns = new_nasal_env();
#    ns.globals = me.score.globals;
    ns.math = math;
#    wd_set_current(me.get_label());
    me.clean_globals(ns);
    me.value = call(me.code,nil,me,ns);
#    wd_set_current();
}
CodeObj.get_single = func(outlet) {
    if(outlet=="value") return me.eval_once?me.value:me.eval();
    else return me.code;
}

var SliderObj = {parents:[ASSingle]};
SliderObj.description = "A simple graphical slider.";
SliderObj.name = "slider";
#SliderObj.new = func(score) {
#    var o = ASSingle.new(score);
SliderObj.init = func(o) {
    ASSingle.init(o);
    o.parents = [SliderObj];
    o.min = -1;
    o.max = 1;
    o.value = 0;
    o.width = 10;
    o.height = 100;
    (o.new_outlet("out")).resolution=0;
    o.add_obj_prop("width",nil,func {o.remake_surface()});
    o.add_obj_prop("value");
    return o;
}
SliderObj.get_single = func(outlet) me.value;
SliderObj.update_geometry = func nil;
SliderObj.draw = func(cr) {
    cairo.set_line_width(cr,1);
#    cairo.set_source_rgb(cr,0.5,0.5,0.5);
    palette.use_color(cr,"fg");
    cairo.move_to(cr,int(me.width/2)+0.5,0);
    cairo.rel_line_to(cr,0,me.height);
    cairo.stroke(cr);
    var y = me.height*((me.value-me.min)/(me.max-me.min));
    cairo.rectangle(cr,0,me.height-y,me.width,y);
#    cairo.set_source_rgb(cr,0,0,0);
    palette.use_color_a(cr,"fg",0.5);
    cairo.fill(cr);
}
#import("debug");
SliderObj.edit_start = func 1;
SliderObj.edit_event = func(ev) {
#print(debug.dump(ev),"\n");
    if((ev.type=="motion-notify" and ev.state["button1-mask"]!=nil)
        or ev.type=="button-press") {
        me.value = ((me.height-ev.y)/me.height)*(me.max-me.min)+me.min;
        if(me.value>me.max) me.value=me.max;
        elsif(me.value<me.min) me.value=me.min;
        me.redraw();
    } elsif(ev.type=="button-release") {
        me.update();    
    }
}

EXPORT=["ASSingle","CodeObj","SliderObj","Comment"];
