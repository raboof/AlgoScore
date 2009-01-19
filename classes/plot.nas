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
import("math");
import("unix");
import("palette");
import("utils");
import("auxinputs");

var MaskPlot = {parents:[algoscore.ASObject]};
MaskPlot.init = func(o) {
    algoscore.ASObject.init(o);
    o.parents = [MaskPlot];
    o.height = 50;
    o.min = -1;
    o.max = 1;
    o.base = 0;
    o.linewidth = 1;
    o.filled = 1;
    o.add_obj_prop("filled",nil,func o.redraw());
    o.add_obj_prop("min value","min");
    o.add_obj_prop("max value","max");
    o.add_obj_prop("base line","base",func o.redraw());
    o.add_obj_prop("linewidth",nil,func o.redraw());

    o.new_outlet("min",0,1);
    o.new_outlet("max",0,1);
}
MaskPlot.val2y = func(v) {
    var h = me.height-2;
    1+h-(((v-me.min)/(me.max-me.min))*h);
}
MaskPlot.draw_line = func(cr,data,dir) {
    var y = 0;
#    cairo.move_to(cr,dir>0?0:me.width,me.val2y(0));
    forindex(var i;data) {
        var ev = data[dir>0?i:(-i-1)];
        var x = me.score.time2x(ev[0]);
#        if(i>0 and !out.interpolate)
#            cairo.line_to(cr,x,y);
        var y = me.val2y(ev[1]);
        cairo.line_to(cr,x,y);
    }
}
MaskPlot.draw = func(cr,ofs,width,last) {
    cairo.move_to(cr,0,0.5+int(me.val2y(me.base)));
    cairo.rel_line_to(cr,width,0);
    palette.use_color(cr,"fg2");
    cairo.stroke(cr);
    cairo.translate(cr,-ofs,0);

    palette.use_color(cr,"fg");
    cairo.new_path(cr);
    me.draw_line(cr,me.outlets.max.data,1);
    me.draw_line(cr,me.outlets.min.data,0);
    cairo.close_path(cr);
    if(me.linewidth) {
        cairo.set_line_width(cr,me.linewidth);
        cairo.stroke_preserve(cr);
    }
    if(me.filled) {
        palette.use_color(cr,"fill");
        cairo.fill(cr);
    }
}

var ASPlotObj = {parents:[auxinputs.AuxInputs,algoscore.ASObject]};
ASPlotObj.init = func(o) {
    algoscore.ASObject.init(o);
    auxinputs.AuxInputs.init(o);
    o.parents = [ASPlotObj];
    o.height = 50;
    o.min = -1;
    o.max = 1;
    o.base = 0;
    o.invert = 0;
    o.add_obj_prop("min value","min");
    o.add_obj_prop("max value","max");
    o.add_obj_prop("base line","base",func o.redraw());
    o.add_obj_prop("invert plot","invert",func o.redraw());
    o.linewidth = 1;
    o.add_obj_prop("linewidth",nil,func o.redraw());
    o.filled = 0;
    o.add_obj_prop("filled",nil,func o.redraw());
    o.labels = 1;
    o.add_obj_prop("labels",nil,func o.redraw());

    o.transfunc_str = "";
    o.transfunc = nil;
    o.add_obj_prop("transfer func","transfunc_str",func {
        if(size(o.transfunc_str)) {
            o.transfunc = compile(o.transfunc_str, o.get_label()~" transfer func");
        } else
            o.transfunc = nil;
        o.caption = o.transfunc_str;
        o.update();
    }).no_eval=1;
    
    o.smooth=0;
    o.add_obj_prop("smooth",nil,func {
        if(o.smooth) {
            o.interpolate = func(out,a,b,x) math.cosipol(a,b,x);
        } else {
            o.interpolate = func(out,a,b,x) math.linipol(a,b,x);
        }
        o.update();
    });

    o.update_aux_inputs();
}
ASPlotObj.val2y = func(v,h=0) {
    if(h==0) h = me.height-2;
#    int(h-(((v-me.min)/(me.max-me.min))*h));
    var m1 = me.invert?me.max:me.min;
    var m2 = me.invert?me.min:me.max;

    1+h-(((v-m1)/(m2-m1))*h);
}

ASPlotObj.get_value = func(o, t) {
    var val = me.default_get_value(o,t);
    if(me.transfunc!=nil) {
        val = call(me.transfunc,nil,nil,
            {x:val,math:math,t:t,outlet:o,length:me.length,in:me.aux_getters});
    }
    return val;
}

ASPlotObj.plot = func(cr,outlet,ofs,width) {

    cairo.select_font_face(cr,"Mono");
    cairo.set_font_size(cr,9);

    var out = me.outlets[outlet];

    var y=0;
    var res=out.resolution>0?out.resolution:me.score.x2time(1);
    var end=out.resolution>0?size(out.data):ofs+width;
     #FIXME: get min/max peaks for the section that fits in one pixel..
    cairo.move_to(cr,0,int(me.val2y(me.base)));
    for(i=0;i<=end;i+=1) {
        var t = i*res;
        var x = me.score.time2x(t);
        if(i>0 and !out.interpolate)
            cairo.line_to(cr,x,y);
        var y = me.val2y(me.get_value(outlet,t));
        cairo.line_to(cr,x,y);
    }
    if(!out.interpolate)
        cairo.line_to(cr,me.width,y);

    cairo.line_to(cr,me.width,int(me.val2y(me.base)));

    cairo.set_line_width(cr,me.linewidth);
    palette.use_color(cr,"fg");
    if(me.filled) {
        cairo.stroke_preserve(cr);
        palette.use_color(cr,"fill");
        cairo.fill(cr);
    } else
        cairo.stroke(cr);

    if(me.labels and out.resolution<=0) {
        var ext = cairo.text_extents(cr,"99.99");
        var scl = (me.width-ext.x_advance)/me.width;
        cairo.set_line_width(cr,1.5);
        forindex(var i;out.data) {
            var ev = out.data[i];
            var tx = me.score.time2x(ev[0]);
            var val = me.get_value(outlet,ev[0]);
#            cairo.move_to(cr,tx-10,me.val2y(ev[1]));
#            cairo.rel_line_to(cr,20,0);
#            cairo.stroke(cr);
            var x = int(tx*scl+2);
            var y = int(me.val2y(val,me.height-12)+10);
            y += (y>me.height/2) ? -5:5;
            cairo.move_to(cr,x,y);
#            cairo.text_path(cr,sprintf("%.2f",ev[1]));
            cairo.text_path(cr,sprintf("%.2f",val));
            palette.use_color(cr,"bg");
            cairo.stroke_preserve(cr);
            palette.use_color(cr,"fg");
            cairo.fill(cr);
        }
    }

}
ASPlotObj.draw = func(cr,ofs,width,last) {
    cairo.move_to(cr,0,0.5+int(me.val2y(me.base)));
    cairo.rel_line_to(cr,width,0);
    palette.use_color(cr,"fg2");
    cairo.stroke(cr);
    cairo.translate(cr,-ofs,0);

    foreach(var k;keys(me.outlets))
        me.plot(cr,k,ofs,width);
}

var Graph = {name:"graph",parents:[ASPlotObj]};
Graph.description = "Plot incomming numerical data.";
Graph.init = func(o) {
    ASPlotObj.init(o);
    o.parents = [Graph];
    o.add_obj_prop("min value","min");
    o.add_obj_prop("max value","max");
    o.new_inlet("in");
}
Graph.draw = func(cr,ofs,width,last) {
    var get = me.inlets.in.val_finder_num(0);
    for(var i=0;i<=width;i+=1) {
        var t = me.score.x2time(i+ofs);
        var y = me.val2y(get(t));
        cairo.line_to(cr,i,y);
    }
    cairo.set_line_width(cr,me.linewidth);
    cairo.stroke(cr);
}

##########################
var SineObj = {name:"sine",parents:[ASPlotObj]};
SineObj.description =
"<b>Sinewave LFO.</b>\n\n"
"<b>Inputs:</b>\n"
"- <tt>freq</tt> : set frequency.\n"
"- <tt>freq_mul</tt> : scale the frequency.\n"
"- <tt>amp</tt> : scale the amplitude.\n\n"
"<b>Properties:</b>\n"
"- <tt>out.freq</tt> : default frequency when <tt>freq</tt> input is not connected.\n"
"- <tt>out.amp</tt> : the initial amplitude.\n"
"- <tt>out.resolution</tt> : the sample interval in seconds.";
SineObj.init = func(o) {
    ASPlotObj.init(o);
    o.parents = [SineObj];
    o.length = 3;
    o.new_inlet("freq");
    o.new_inlet("freq_mul");
    o.new_inlet("amp");
    var out = o.new_outlet("out",0.02,1);
    out.freq = 2;
    out.amp = 1;
    o.add_out_prop("out","freq");
    o.add_out_prop("out","resolution");
    o.add_out_prop("out","amp");
}
SineObj.generate = func {
    me.update_aux_getters();
    var out = me.outlets.out;
    var amp = me.inlets["amp"].val_finder_num(1);
    var frq = me.inlets["freq"].val_finder_num(out.freq);
    var frqm = me.inlets["freq_mul"].val_finder_num(1);
    out.data = setsize([],me.length/out.resolution);
    me.caption = out.freq~" Hz "~me.transfunc_str;
    var phase = 0;
#    var r = out.freq * out.resolution * math.pi * 2;
    var r = out.resolution * math.pi * 2;
    var t = 0;
    for(var i=0; i<size(out.data); i+=1) {
#        out.data[i] = me.apply_transfunc(math.sin(phase) * out.amp * amp(t));
    
        out.data[i] = math.sin(phase) * out.amp * amp(t);
        phase += r * frqm(t) * frq(t);
        t += out.resolution;
    }
    0;
}

var MSineObj = {name:"multisine",parents:[ASPlotObj]};
#SineObj.new = func(score) {
#    var o = ASPlotObj.new(score);
MSineObj.init = func(o) {
    ASPlotObj.init(o);
    o.parents = [MSineObj];
#    o.min = -1;
#    o.max = 1;
    o.length = 3;
    o.height = 70;

    o.new_inlet("freq");
    o.new_inlet("amp");

    var out = o.new_outlet("out1",0.02,1);
    out.freq = 2;
    out.amp = 1;

    o.out_prop_list=["freq","resolution","amp"];
    
    o.properties["n_outs"]={
        set:func(v) {
            var sz=size(o.outlets);
            if(v<sz) {
                for(var i=sz;i>=v;i-=1) {
                    var n="out"~(i+1);
                    delete(o.outlets,n);
                    foreach(var k;o.out_prop_list)
                        o.del_out_prop(n,k);
                }
            } else {
                for(var i=sz;i<v;i+=1) {
                    var out = o.new_outlet("out"~(i+1));
                    out.resolution = 0.02;
                    out.freq = 1*i;
                    out.amp = 1;
                }
                o.update_out_props();
            }
            o.update();
        },
        get:func size(o.outlets)
    };
   
    o.update_out_props();
      
    return o;
}
MSineObj.update_out_props = func {
    foreach(var k;keys(me.outlets)) {
        foreach(var n;me.out_prop_list)
            me.add_out_prop(k,n);
    }
}
MSineObj.generate = func {
    me.update_aux_getters();
    
    var amp = me.inlets["amp"].val_finder_num(1);
    var frq = me.inlets["freq"].val_finder_num(1);
    
    foreach(var k; keys(me.outlets)) {
        var out = me.outlets[k];
        out.data = setsize([],me.length/out.resolution);
        var phase = 0;
        var r = out.freq * out.resolution * math.pi * 2;
        var t = 0;
        for(var i=0; i<size(out.data); i+=1) {
            out.data[i] = math.sin(phase) * out.amp * amp(t);
            phase += r * frq(t);
            t += out.resolution;
        }
    }
    0;
}

var Mask = {name:"maskshape",parents:[MaskPlot]};
Mask.description = "Like <tt>shape</tt> but with min/max curves.";
Mask.init = func(o) {
    MaskPlot.init(o);
    o.parents=[Mask];
    o.length=3;
    o.shape_min = [];
    o.shape_max = [];
#    o.add_out_prop("min","data");
#    o.add_out_prop("max","data");
#    o.outlets.max.data=[[0,0.5],[1.5,1],[2,0.7]];
#    o.outlets.min.data=[[0,0.3],[0.5,0],[2,0.1]];
    o.add_obj_prop("shape_min");
    o.add_obj_prop("shape_max");
}
Mask.gen_data = func(shape) {
    data = [];
    var r = me.length/(size(shape)-1);
    var t = 0;
    foreach(var s;shape) {
        if(s>me.max) me.max=s;
        elsif(s<me.min) me.min=s;
        append(data,[t,s]);
        t += r;
    }
    return data;
}
Mask.generate = func {
    me.outlets.min.data = me.gen_data(me.shape_min);
    me.outlets.max.data = me.gen_data(me.shape_max);
    0;
}

var Shape = {name:"shape",parents:[ASPlotObj]};
Shape.description =
"<b>Simple ramps between values.</b>\n\n"
"<tt>shape data</tt> property sets the sequence of"
" values, which are evenly spaced along the"
" length of the object.";
Shape.init = func(o) {
    ASPlotObj.init(o);
    o.parents = [Shape];
    o.min = 0;
    o.max = 1;
    o.length = 3;
    o.shape = [0,1];
    o.new_outlet("out",0,1);
    o.add_obj_prop("shape data","shape");
}
Shape.generate = func {
    me.update_aux_getters();
    var out = me.outlets["out"];
    out.data = [];
    var r = me.length/(size(me.shape)-1);
    var t = 0;
    foreach(var s;me.shape) {
        if(s>me.max) me.max=s;
        elsif(s<me.min) me.min=s;
        append(out.data,[t,s]);
        t += r;
    }
    0;
}

var Comparator = {name:"comparator",parents:[ASPlotObj]};
Comparator.description =
"<b>Compare two numerical inputs.</b>\n\n"
"<tt>min</tt> and <tt>max</tt> properties sets the output value"
" for when the <tt>in</tt> input is below or above the"
" <tt>tresh</tt> input.\n\n"
"<tt>resolution</tt> property sets sample interval in seconds.";
Comparator.init = func(o) {
    ASPlotObj.init(o);
    o.parents = [Comparator];
    o.length = 5;
    o.min = 0;
    o.max = 1;
    o.resolution = 0.01;
    o.new_outlet("out",0,0);
    o.new_inlet("in");
    o.new_inlet("tresh");
    o.add_obj_prop("resolution");
}
Comparator.generate = func {
    me.update_aux_getters();
    var out = me.outlets["out"];
    out.data = [];
    var get_in = me.inlets["in"].val_finder_num(0);
    var get_tresh = me.inlets["tresh"].val_finder_num(0);
    me.alignments = [];
    var t = 0;
    var old = nil;
    while(t<me.length) {
        var val = get_in(t)>get_tresh(t)?me.max:me.min;
        if(val!=old) {
            append(out.data,[t,val]);
            old=val;
            append(me.alignments,t);
        }
        t += me.resolution;
    }
    0;
}

var NoiseObj = {name:"noise",parents:[ASPlotObj]};
NoiseObj.description =
"<b>Random LFO.</b>\n\n"
"<b>Inputs:</b>\n"
"- <tt>max</tt> : upper value limit.\n"
"- <tt>min</tt> : lower value limit.\n\n"
"<b>Properties:</b>\n"
"- <tt>seed</tt> : initial random seed.\n"
"- <tt>randomizer</tt> : the code used to get random number."
" aux inputs are available as <tt>in</tt>, current time as <tt>t</tt>"
" and last value as <tt>last</tt>.\n"
"- <tt>out.resolution</tt> : rate in seconds.\n"
"- <tt>out.interpolate</tt> : 0 for stepped values"
" and 1 for interpolated lines between values";
NoiseObj.init = func(o) {
    ASPlotObj.init(o);
    o.parents = [NoiseObj];
    o.length = 7;
    o.seed = unix.time();
    o.add_obj_prop("seed");
    o.new_inlet("max");
    o.new_inlet("min");
    o.new_outlet("out",0.01,0);
    o.add_out_prop("out","resolution");
    o.add_out_prop("out","interpolate");
    o.randomizer = "math.rand()*(max-min)+min";
    o.add_obj_prop("randomizer",nil,func {
        o.update_randfunc();
        o.update();
    });
    o.update_randfunc();
}
NoiseObj.update_randfunc = func {
    me.random_func = compile(me.randomizer,me.get_label()~" randomizer");
}
NoiseObj.generate = func {
    me.update_aux_getters();
    var out = me.outlets["out"];
    var sz = int(me.length/out.resolution);
    out.data = setsize([],sz);
    var t=0;
    var get_max = me.inlets["max"].val_finder_num(me.max);
    var get_min = me.inlets["min"].val_finder_num(me.min);
    math.seed(me.seed);
    var ns = {math:math,last:0};
    for(var i=0;i<sz;i+=1) {
        ns.min = get_min(t);
        ns.max = get_max(t);
        ns.t = t;
        ns.in = me.aux_getters;
#        ns.last = out.data[i] = call(me.random_func,nil,nil,ns,var err=[]);
        ns.last = out.data[i] = call(me.random_func,nil,nil,ns);
#        if(size(err)) {
#            printerr(utils.stacktrace(err));
#            break;
#        }
#        out.data[i] = math.rand2(get_min(t), get_max(t));
        t += out.resolution;
    }
    0;
}

var EvGraph = {name:"evgraph",parents:[algoscore.ASObject]};
EvGraph.description =
"<b>Plot discrete events.</b>\n\n"
"<tt>events</tt> input takes events in the format <tt>[val1, ...]</tt>\n\n"
"<b>Properties:</b>\n"
"- <tt>y_parm</tt> : what element of the event should"
" describe the vertical position of the event.\n"
"- <tt>y2_parm</tt> : what element of the event should"
" describe the vertical end-position of the event.\n"
"- <tt>dur_parm</tt> : what element should"
" describe the length of the event.\n"
"- <tt>black_parm</tt> : what element should describe"
" the opacity of the event.\n"
"- <tt>size_parm</tt> : what element should describe"
" the size of the onset marker. Use <tt>size_scale</tt> to scale it.\n"
"- <tt>grid</tt> : y-space division.";
EvGraph.init = func(o) {
    algoscore.ASObject.init(o);
    o.parents = [EvGraph];
    o.y_parm = 0;
    o.dur_parm = nil;
    o.black_parm = nil;
    o.size_parm = nil;
    o.size_scale = 10;
    o.y2_parm = nil;
    o.height = 200;
    o.new_inlet("events");
    o.add_obj_prop("y_parm");
    o.add_obj_prop("y2_parm");
    o.add_obj_prop("dur_parm");
    o.add_obj_prop("black_parm");
    o.add_obj_prop("size_parm");
    o.add_obj_prop("size_scale");
    o.grid = 12;
    o.add_obj_prop("grid");
}
EvGraph.draw = func(cr,ofs,width,last) {
    cairo.translate(cr,0.5,0.5);
    cairo.set_line_width(cr,1);

    palette.use_color(cr,"fg2");
        
    if(ofs==0) cairo.move_to(cr,0,15);
    cairo.line_to(cr,0,0);
    cairo.rel_line_to(cr,width,0);
    if(last) cairo.rel_line_to(cr,0,15);
    cairo.stroke(cr);

    if(ofs==0) cairo.move_to(cr,0,me.height-15);
    cairo.line_to(cr,0,me.height);
    cairo.rel_line_to(cr,width,0);
    if(last) cairo.rel_line_to(cr,0,-15);
    cairo.stroke(cr);
   
    var min = var max = nil;
    var b_min = var b_max = 0;
    var ev_in = me.inlets["events"];
    var ev_cons = ev_in.get_connections();
    foreach(var con;ev_cons) {
        for(var i=0;i<con.datasize;i+=1) {
            var ev = con.get_event(i);
            if(ev[1]==nil) continue;
            if(typeof(ev[1])=="vector") var p = ev[1];
            else var p = [ev[1]];
            var y = p[me.y_parm];
            if(max==nil or y>max) max=y;
            if(min==nil or y<min) min=y;
            if(me.black_parm!=nil) {
                var b = p[me.black_parm];
                if(b>b_max) b_max=b;
                elsif(b<b_min) b_min=b;
            }
        }
    }
    
    if(ofs==0) {
        cairo.select_font_face(cr,"Mono");
        cairo.set_font_size(cr,9);
        cairo.move_to(cr,1,9);
        cairo.show_text(cr,sprintf("%.2f",max));
        cairo.move_to(cr,1,me.height-2);
        cairo.show_text(cr,sprintf("%.2f",min));
    }
    if(max==nil) max=1;
    if(min==nil) min=1;
    var ngrids = (max-min)/me.grid;
    cairo.set_line_width(cr,0.5);
#    palette.use_color_a(cr,"fg",0.5);
    for(var i=0;i<ngrids;i+=1) {
        var y = int(i*(me.height/ngrids));
        cairo.move_to(cr,0,y);
        cairo.rel_line_to(cr,width,0);
        cairo.stroke(cr);
    }

    cairo.translate(cr,-ofs,0); #FIXME
    palette.use_color(cr,"fg");
    cairo.set_line_width(cr,1);
    foreach(var con;ev_cons) {
        for(var i=0;i<con.datasize;i+=1) {
            var ev = con.get_event(i);
            if(ev[1]==nil) continue;
            var t = ev[0];
            var x = me.score.time2x(t);
            if(typeof(ev[1])=="vector") var p = ev[1];
            else var p = [ev[1]];
            var yp = p[me.y_parm];
            var l = me.dur_parm!=nil?me.score.time2x(p[me.dur_parm]):3;
            var y = me.val2y(yp,min,max); #+0.5;
            var y2 = me.y2_parm!=nil?me.val2y(p[me.y2_parm],min,max):y;
            if(me.size_parm!=nil) {
#                cairo.set_line_width(cr,1);
                var s = p[me.size_parm]*me.size_scale;
                cairo.move_to(cr,x,y-s);
                cairo.rel_line_to(cr,0,s*2);
                cairo.rel_line_to(cr,5,-s);
#                cairo.line_to(cr,x,y-s);
                cairo.close_path(cr);
#                cairo.stroke(cr);
            }
#            cairo.set_line_width(cr,2);
            cairo.move_to(cr,x,y);
            cairo.rel_line_to(cr,l,y2-y);
            if(me.black_parm!=nil) {
                var b = p[me.black_parm];
                b = (b-b_min)/(b_max-b_min);
                palette.use_color_a(cr,"fg",b);
            }
            cairo.stroke(cr);
        }
    }
}
EvGraph.val2y = func(v,min,max) {
    var h = me.height;
    int(h-(((v-min)/(max-min))*(h-2)+1));
}

var Jitter = {name:"jitter",parents:[ASPlotObj]};
Jitter.description =
"<b>Random line-curve.</b>\n\n"
"<tt>min duration</tt> and <tt>max duration</tt> sets"
" default min and max duration in seconds. Can also be"
" controlled with <tt>mindur</tt> and <tt>maxdur</tt> inlets.\n"
"<tt>time_randomizer</tt> and <tt>value_randomizer</tt> sets the"
" code used to get random numbers."
" aux inputs are available as <tt>in</tt>, current time as <tt>t</tt>"
" and last value as <tt>last</tt>.";
Jitter.init = func(o) {
    ASPlotObj.init(o);
    o.parents = [Jitter];
    o.min = 0;
    o.max = 1;
    o.length = 3;
    o.mindur = 0.1;
    o.maxdur = 1.0;
    o.seed = unix.time();
    o.add_obj_prop("seed");
    o.parms = [0,1];
    o.new_outlet("out",0,1);
    o.add_out_prop("out","interpolate");
    o.add_obj_prop("min duration","mindur");
    o.add_obj_prop("max duration","maxdur");
    o.start_val = 0;
    o.end_val = 0;
    o.add_obj_prop("start value","start_val");
    o.add_obj_prop("end value","end_val");
    o.new_inlet("mindur");
    o.new_inlet("maxdur");
    o.time_randomizer = "math.rand()*(max-min)+min";
    o.value_randomizer = "math.rand()*(max-min)+min";
    o.add_obj_prop("time_randomizer",nil,func {
        o.update_randfuncs();
        o.update();
    }).no_eval=1;
    o.add_obj_prop("value_randomizer",nil,func {
        o.update_randfuncs();
        o.update();
    }).no_eval=1;
    o.update_randfuncs();
}

Jitter.update_randfuncs = func {
    me.t_random_func = compile(me.time_randomizer,me.get_label()~" time randomizer");
    me.v_random_func = compile(me.value_randomizer,me.get_label()~" value randomizer");
}

Jitter.generate = func {
    me.update_aux_getters();
    var out = me.outlets["out"];
    var get_min = me.inlets.mindur.val_finder_num(me.mindur);
    var get_max = me.inlets.maxdur.val_finder_num(me.maxdur);
    out.data = [];
    math.seed(me.seed);
    var t = 0;
    var v = me.start_val;
    var ns = {math:math};
    while(1) {
        if(t>me.length) {
            append(out.data,[me.length,me.end_val]);
            break;
        }
        append(out.data,[t,v]);
#        if(t>me.length) break;
#        t += math.rand2(me.mindur,me.maxdur);
        var mindur = get_min(t);
        var maxdur = get_max(t);
        if(maxdur<=0) maxdur=0.1;
#        if(mindur+maxdur <= 0) t += 1; #doesn't seem to work
#        else 
        ns.t = t;
        ns.in = me.aux_getters;
        ns.min = mindur;
        ns.max = maxdur;
        ns.last = v;
        t += call(me.t_random_func,nil,nil,ns);#,var err=[]);
#        if(size(err)) {
#            printerr(utils.stacktrace(err));
#            break;
#        }
        ns.min = me.min;
        ns.max = me.max;
        v = call(me.v_random_func,nil,nil,ns);#,var err=[]);
#        if(size(err)) {
#            printerr(utils.stacktrace(err));
#            break;
#        }
        
#        t += math.rand2(mindur,maxdur);
#        v = math.rand2(me.min,me.max);
    }
    0;
}

var Linseg = {name:"linseg",parents:[ASPlotObj]};
Linseg.description =
"<b>User defined break-point curve.</b>\n\n"
"<tt>shape data</tt> property is in the format"
" <tt>[val1, time1, val2, time2, val3, ...]</tt>\n"
"if <tt>proportional</tt> is zero, times are in seconds,"
" otherwise relative each other and fitted into the"
" object length.";
Linseg.init = func(o) {
    ASPlotObj.init(o);
    o.parents = [Linseg];
    o.min = 0;
    o.max = 1;
    o.proportional = 1;
    o.length = 3;
    o.shape = [0,2,1,2,0];
    o.new_outlet("out",0,1);
    o.add_obj_prop("shape data","shape");
    o.add_obj_prop("proportional");
}
Linseg.generate = func {
    me.update_aux_getters();
    var out = me.outlets["out"];
    out.data = [[0,me.shape[0]]];
    var t = 0;
    for(var i=1;i<size(me.shape);i+=2) {
        var t += me.shape[i];
        var s = me.shape[i+1];
        if(s>me.max) me.max=s;
        elsif(s<me.min) me.min=s;
        append(out.data,[t,s]);
    }
    if(me.proportional) {
        var f = me.length/t;
        foreach(var ev;out.data) {
            ev[0]*=f;
        }
    } elsif(me.length!=t) {
        me.set_prop("length",t);
    }
    return 0;
}

var MaskLinseg = {name:"masklinseg",parents:[MaskPlot]};
MaskLinseg.description = "Like <tt>linseg</tt> but with min/max curves.";
MaskLinseg.init = func(o) {
    MaskPlot.init(o);
    o.parents=[MaskLinseg];
    o.length=3;
    o.proportional = 1;
    o.shape_min = [0,2,-1,1,0];
    o.shape_max = [0,1,1,2,0];
    o.add_obj_prop("shape_min");
    o.add_obj_prop("shape_max");
    o.add_obj_prop("proportional");
}
MaskLinseg.gen_data = func(shape) {
    var data = [[0,shape[0]]];
    var t = 0;
    for(var i=1;i<size(shape);i+=2) {
        var t += shape[i];
        var s = shape[i+1];
        if(s>me.max) me.max=s;
        elsif(s<me.min) me.min=s;
        append(data,[t,s]);
    }
    if(me.proportional) {
        var f = me.length/t;
        foreach(var ev;data) {
            ev[0]*=f;
        }
    } elsif(me.length!=t) {
        me.set_prop("length",t);
    }
    return data;
}
MaskLinseg.generate = func {
    me.outlets.min.data = me.gen_data(me.shape_min);
    me.outlets.max.data = me.gen_data(me.shape_max);
    0;
}

EXPORT=["ASPlotObj","SineObj","Shape","NoiseObj","Comparator","Graph","EvGraph",
"MaskPlot","Mask","Jitter","Linseg","MaskLinseg"];
