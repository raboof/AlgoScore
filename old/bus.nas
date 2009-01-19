# Copyright 2008, Jonatan Liljedahl
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

var BusObj = {parents:[algoscore.ASObject]};
BusObj.init = func(o) {
    algoscore.ASObject.init(o);
    o.parents = [BusObj];
    o.height = 10;
#    o.force_label = 1;
    var in = o.new_inlet("A").is_dyn_input = 1;
#    o.new_outlet("out",0);
}
BusObj.connect_done = func(src,out,in) {
    var i = me.inlets[in];
    if(i["is_dyn_input"]==1) {
        in~="";
        in[0] += 1;
        if(!contains(me.inlets,in)) {
            me.new_inlet(in).is_dyn_input=1;
        }
    }
}
BusObj.draw = func(cr,ofs,width,last) {
    cairo.set_line_width(cr,2);
    cairo.move_to(cr,0,me.height/2);
    cairo.rel_line_to(cr,width,0);
    if(last) {
        cairo.rel_move_to(cr,0,-me.height/2);
        cairo.rel_line_to(cr,0,me.height);
    }
    cairo.stroke(cr);
}
BusObj.get_datasize = func 1;
BusObj.get_event = func(out,t) {
    return [0,me.get_value(out,t)];
}

var SumBus = {name:"sum",parents:[BusObj]};
SumBus.description = "<b>Sum numerical inputs</b>";
SumBus.init = func(o) {
    BusObj.init(o);
    o.parents = [SumBus];
    o.scale = 0;
    o.add_obj_prop("scale");
    o.new_outlet("out",0);
}
SumBus.get_value = func(out,t) {
    var sum = 0;
    var x = 0;
    foreach(var in;keys(me.inlets)) {
        if(me.inlets[in].connected) {
            var get = me.inlets[in].val_finder(0);
            sum += get(t);
            x += 1;
        }
    }
    if(me.scale)
        return sum*me.scale;
    else
        return sum/x;
}

EXPORT=["BusObj","SumBus"];
