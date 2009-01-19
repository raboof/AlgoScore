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

var TimeGrid = {
    name: "timegrid",
    description:
        "<b>Timegrid with alignmentpoints and controllable tempo.</b>",
    parents: [algoscore.ASObject],
    init: func(o) {
        algoscore.ASObject.init(o);
        o.parents = [TimeGrid];
        o.height = 20;
        o.divisor = 4;
        o.bpm = 120;
        o.new_inlet("tempo");
        o.new_outlet("out",0,0);
        var set_rate = func {
            o.rate = 60/(o.bpm*(o.divisor/4));        
            o.update();
        }
        set_rate();
        o.add_obj_prop("rate (s)","rate",func {
            o.bpm = (60/o.rate)/(o.divisor/4);
            o.update();
        });
        o.timegrids_enable = 1;
        o.timegrid_pattern = 4;
        o.add_obj_prop("beats per minute","bpm",set_rate);
        o.add_obj_prop("divisor","divisor",set_rate);
        o.add_obj_prop("timegrid in score","timegrids_enable");
        o.add_obj_prop("timegrid pattern","timegrid_pattern");
        o.add_obj_prop("timegrid direction","timegrid_pos");
    },
    generate: func {
        me.caption = "bpm: "~me.bpm;
        var out = me.outlets["out"];
        out.data = [];
        me.timegrids = [];
        var get_tmp = me.inlets["tempo"].val_finder(0);
        for(var t=0;t<=me.length;t+=me.rate/math.pow(2,get_tmp(t))) {
            append(out.data,[t,0]);
            append(me.timegrids,t);
        }
    },
    get_alignments: func me.timegrids,
    draw: func(cr,ofs,width,last) {
        foreach(var ev;me.outlets["out"].data) {
            var t = ev[0];
            var x = int(me.score.time2x(t));
            if(x>=ofs) {
                if(x-ofs>width) break;
                cairo.move_to(cr,x-ofs+0.5,0);
                cairo.rel_line_to(cr,0,me.height);
            }
        }
        cairo.set_line_width(cr,1);
        cairo.stroke(cr);
        cairo.set_line_width(cr,2);
        cairo.move_to(cr,0,int(me.height/2));
        cairo.rel_line_to(cr,width,0);
        cairo.stroke(cr);
    }
};
EXPORT=["TimeGrid"];
