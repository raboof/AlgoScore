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
import("gtk");
import("palette");
import("math");
import("utils");
import("auxinputs");

var get_multiline = func(cr,s) {
    var lines=split("\n",s);
    while(size(lines) and lines[-1]=="") pop(lines); #remove empty last line
    var fx = cairo.font_extents(cr);
    var ret = {
        width:0,
        height:fx.height*(size(lines) or 1),
        lheight:fx.height,
        ascent:fx.ascent,
        lines:lines
    };
    foreach(var l;lines) {
        var ext = cairo.text_extents(cr,l);
        if(ext.x_advance>ret.width) ret.width=ext.x_advance;
    }
    if(size(lines)==0) ret.width=10;
    return ret;
}

var TextLayer = {source_name:"TextLayer"};
TextLayer.init = func(o) {
    o.text = "";
    o.font_size = 10;
    o.margin = 6;
    delete(o.properties,"height");
    o.add_obj_prop("font_size","font_size",func {
#        o.surface = nil;
        o.remake_surface();
#        o.redraw();
    });
#    append(o.save_symbols,"text");
    o.add_obj_prop("text",nil,func {
        o.text_changed();
    }).no_edit=1;
    o._win = nil;
}
#TextLayer.text_changed = func nil;
TextLayer.update_text_geometry = func(cr,txt) {
    cairo.select_font_face(cr,"Mono");
    cairo.set_font_size(cr,me.font_size);
#    txt = size(txt)?txt:"(NO TEXT)";
    if(!size(txt)) txt="(NO TEXT)";
    me.lines = get_multiline(cr,txt);
    me.lines.height += me.margin;
    me.lines.width += me.margin;
}
TextLayer.update_geometry = func(cr) {
    me.update_text_geometry(cr,me.text);
    me.height = me.lines.height;
    me.width = me.lines.width;
}
TextLayer.draw_text = func(cr) {
    cairo.select_font_face(cr,"Mono");
    cairo.set_font_size(cr,me.font_size);
    var y = me.lines.ascent+me.margin/2;
    foreach(var l;me.lines.lines) {
        cairo.move_to(cr,me.margin/2,y);
        cairo.show_text(cr,l);
        y += me.lines.lheight;
    }
}
TextLayer.draw = func(cr) {
    me.draw_text(cr);
}
TextLayer.edit_start = func {
    me.edit_text();
    return 0;
}
TextLayer.edit_text = func {
    if(me._win!=nil) {
        me._win.raise();
        return;
    }
    var w = gtk.Window("title",me.get_label()~" text");
    me._win = w;
    w.set("default-width",400,"default-height",200);
    var close = func { me._win=nil; w.hide(); w.destroy(); }
    w.connect("delete-event",close);
    var box = gtk.VBox();
    var txt = gtk.TextView("name","monotext");
    txt.set("left-margin",4,"right-margin",4);
    var sw = gtk.ScrolledWindow("hscrollbar-policy","automatic","vscrollbar-policy","automatic");
    sw.add(txt);
    box.pack_start(sw);
    w.add(box);
    var buf = txt.get("buffer");
    buf.set("text",me.text);
    var set_text = func {
        me.text = buf.get("text");
        me.text_changed();
    }
    var bb = gtk.HButtonBox("layout-style","end","spacing",4,"border-width",4);
    var b = gtk.Button("use-stock",1,"label","gtk-apply");
    b.connect("clicked",set_text);
    bb.add(b);
    var b = gtk.Button("use-stock",1,"label","gtk-ok");
    b.connect("clicked",func { set_text(); close()});
    bb.add(b);
    box.pack_start(bb,0);
    w.show_all();
}
TextLayer.text_changed = func {
#    me.surface = nil;
    me.remake_surface();
    me.update();
}

var TextBus = {parents:[TextLayer,algoscore.ASObject]};
TextBus.init = func(o) {
    algoscore.ASObject.init(o);
    TextLayer.init(o);
    o.parents = [TextBus];
    o.alt_score_text = "";
    o.add_obj_prop("alt_score_text",nil,func o.remake_surface(),1);
}
TextBus.update_geometry = func(cr) {
    me.update_text_geometry(cr,size(me.alt_score_text)?me.alt_score_text:me.text);
    me.height = int(me.lines.height+10);
    me.width = int(me.score.time2x(me.length));
    if(me.width<me.lines.width) me.width=me.lines.width;
}
TextBus.xy_inside = func(x,y) {
    return (
        (x >= me.xpos and x <= me.score.time2x(me.start+me.length)
     and y >= me.ypos+me.lines.height and y <= me.ypos+me.height)
     or (x >= me.xpos and x <= me.xpos+me.lines.width
     and y >= me.ypos and y <= me.ypos+me.lines.height)
    ) ? 1 : 0;
}
TextBus.get_con_top_ypos = func(x) {
    return (x>me.xpos+me.lines.width) ? me.ypos+me.lines.height+4 : me.ypos;
}
TextBus.get_con_bottom_ypos = func(x) {
    return me.ypos+me.height-4;
}
TextBus.draw = func(cr,ofs,width,last) {
    if(ofs==0) {
        me.draw_text(cr);
        cairo.rectangle(cr,0.5,0.5,me.lines.width,me.lines.height);
        palette.use_color(cr,"fg2");
        cairo.stroke(cr);
    }

    cairo.set_line_width(cr,2);
    cairo.move_to(cr,0,me.height-5);
#    cairo.move_to(cr,0.5,0.5+me.height-5);

    if(last)
        cairo.rel_line_to(cr,int(me.score.time2x(me.length))-ofs,0);
    else
        cairo.rel_line_to(cr,int(width),0);

    palette.use_color(cr,"fg");
#    cairo.stroke(cr);

    if(last) {
        cairo.rel_move_to(cr,0,-5);
        cairo.rel_line_to(cr,0,10);
#        cairo.set_line_width(cr,1);
#        cairo.stroke(cr);
    }
    cairo.stroke(cr);
}

CodeBus = {parents:[auxinputs.AuxInputs,TextBus]};
CodeBus.init = func(o) {
    TextBus.init(o);
    auxinputs.AuxInputs.init(o);
    o.parents = [CodeBus];
    o.code = nil;
#    o.new_outlet("out",0,0);
    o.aux_inputs = ['A','B','C'];
    o.update_aux_inputs();
    
    var make_outlets = func {
        if(typeof(o.user_outlets)=="vector") {
            var h = {};
            foreach(k;o.user_outlets) {
                h[k]=0;
            }
            o.user_outlets=h;
        }
        foreach(k;keys(o.outlets))
            o.outlets[k].keep_me=0;
        foreach(k;keys(o.user_outlets)) {
            var ipol = o.user_outlets[k];
            if(!contains(o.outlets,k)) {
                o.new_outlet(k);
#                o.add_out_prop(out,"interpolate");
            }
            o.outlets[k].interpolate=ipol;
            o.outlets[k].keep_me=1;
        }
        foreach(k;keys(o.outlets)) {
            if(!o.outlets[k].keep_me) {
                delete(o.outlets,k);
#                o.del_out_prop(k,"interpolate");
            }
        }
        o.update();
    }
    
    o.user_outlets = {out:0};
    o.add_obj_prop("outlets","user_outlets",make_outlets);
    make_outlets();
}
CodeBus.compile = func {
    var compfn = func compile(me.text, me.get_label()~" code");
    var code = call(compfn);
    me.code = code;
}
CodeBus.text_changed = func {
    me.compile();
    me.remake_surface();
    me.update();
}

FuncBus = {parents:[CodeBus]};
FuncBus.name = "funcbus";
FuncBus.description =
"<b>Process inputs through nasal code.</b>\n\n"
"The code runs with the following variables available:\n"
"- <tt>in</tt> : a table of functions f(t) to get value from input at time t, named after"
" the inputs specified in the <tt>aux_inputs</tt> property."
" example: <tt>return x * in.A(t);</tt>\n"
"- <tt>t</tt> : time of the value asked for by the receieving object.\n"
"- <tt>ev</tt> : the value of the 'event' inlet at time t.\n"
"- <tt>x</tt> : ramp from 0.0 to 1.0 along the length of the object.\n"
"- <tt>outlet</tt> : the name of the outlet asked for by the receieving object."
" The available outlets are specified in the <tt>outlets</tt> property.\n"
"- <tt>length</tt> : the length of the object.\n"
"- <tt>math</tt> : the math library (sin, pow, mod, etc...)\n"
"- <tt>init</tt> : 1 at first eval after update.\n"
"- <tt>G_set(sym,val)</tt> : set global variable.\n"
"- <tt>G_get(sym)</tt> : get global variable.\n\n"
"If a destination object asks for an event by index, t will be set to"
" the corresponding event of the 'event' inlet, both in the <tt>t</tt>"
" variable and in the returned event. The 'ev' variable will then hold"
" the actual value of the event. This can be used to synthesize"
" events by combining multiple sources or expressions.\n\n"
"For each outlet, an <tt>out.interpolate</tt> property will be created.";
# note: problem with the 'init' variable is that it's only set
# after *this* object update, not receiving objs. but it could be
# used to set up an array of data which is then fetched when init is 0,
# but this would be better to do with a datagen object.

FuncBus.init = func(o) {
    CodeBus.init(o);
    o.parents = [FuncBus];
    o.first_run = 0;
    o.new_inlet("event");
}
FuncBus.generate = func {
    me.update_aux_getters();
    me.first_run = 1;
    me.ev_get = me.inlets.event.val_finder();
    me.ev_cons = me.inlets.event.get_connections();
    me.eval_ns = new_nasal_env();
    return 0;
}
FuncBus.get_value = func(out,t,ev=nil) {
    if(me.code!=nil) {
        var ns = me.eval_ns;
        ns.in = me.aux_getters;
        ns.ev = ev==nil?me.ev_get(t):ev;
        ns.t = t;
        ns.x = math.clip(t/me.length,0,1);
        ns.outlet = out;
        ns.math = math;
        ns.length = me.length;
        ns.init = me.first_run;
        me.clean_globals(ns);
        var val = call(me.code,nil,me,ns);
        me.first_run = 0;
        return val;
    } else
        return nil;
}
FuncBus.get_datasize = func(out) {
    me.inlets.event.datasize;
}
FuncBus.get_event = func(out,i) {
    foreach(c;me.ev_cons) {
        if(i<c.datasize) {
            var ev = c.get_event(i);
            var t = ev[0];
            return [t,me.get_value(out,t,ev[1])];
        } else
            i -= c.datasize;
    }
    return nil;
}

DataGen = {parents:[CodeBus]};
DataGen.name = "datagen";
DataGen.description =
"<b>Generate data or events with nasal code.</b>\n\n"
"The code runs with the following variables available:\n"
"- <tt>length</tt> : the length of the object. (read-only)\n"
"- <tt>in</tt> : a table of functions f(t) to get value from input at time t, named after"
" the inputs specified in the <tt>aux_inputs</tt> property."
" example: <tt>x = in.A(t);</tt>\n"
"- <tt>out.resolution</tt> : sample interval, or 0 for event-data.\n"
"- <tt>out.interpolate</tt> : 1 to interpolate between values.\n"
"- <tt>out.data</tt> : the output data, initialized to [].\n"
"- <tt>out.transfunc</tt> : custom transfer function as f(value,time).\n"
"- <tt>math</tt> : the math library (sin, pow, mod, etc...)\n"
"- <tt>inlets</tt> : direct access to inlets, for use of Inlet.get_connections() and such.\n"
"- <tt>G_set(sym,val)</tt> : set global variable.\n"
"- <tt>G_get(sym)</tt> : get global variable.\n\n"
"Multiple outlets may be specified in the <tt>outlets</tt> property."
" They will be available just like 'out' above but named accordingly.";

DataGen.init = func(o) {
    CodeBus.init(o);
    o.parents = [DataGen];
}
DataGen.generate = func {
#    me.compile(); #does this need to be here?
    if(me.code==nil) return;
    me.update_aux_getters();
    var ns = new_nasal_env();
    foreach(k;keys(me.outlets)) {
        ns[k] = me.outlets[k];
        ns[k].data = [];
        ns[k].transfunc = nil;
    }
    ns.in = me.aux_getters;
    ns.inlets = me.inlets;
    ns.input = me.aux_getters; #deprecated
    ns.length = me.length;
    ns.math = math;
    me.clean_globals(ns);
    call(me.code,nil,me,ns);
    foreach(k;keys(me.outlets)) {
        var out = me.outlets[k];
        if(out.resolution==0) out.data = sort(out.data,func(a,b) a[0]>b[0]);
        print(me.get_label(),":",k," generated ",size(out.data)," events\n");
    }

    0;
}
DataGen.get_value = func(o,t) {
    var val = me.default_get_value(o,t);
    var tf = me.outlets[o].transfunc;
    if(tf==nil) return val;
    else return tf(val,t);
}
DataGen.get_event = func(o,i) {
    var ev = me.default_get_event(o,i);
    var tf = me.outlets[o].transfunc;
    if(tf==nil) return ev;
    else return [ev[0],tf(ev[1],ev[0])];
}
EXPORT=["TextLayer","TextBus","CodeBus","DataGen","FuncBus"];
