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

import("outbus");
import("playbus");
import("bits");

OscBus = {name:"osc_bus",parents:[outbus.OutBus]};
OscBus.description =
"<b>Output OSC (OpenSoundControl) messages.</b>\n\n"
"<b>Properties:</b>\n"
"- <tt>osc_address</tt> : destination URL, like 'osc.udp://localhost:7770'\n"
"- <tt>resolution</tt> : resolution of interpolated inputs.\n"
"- <tt>controllers</tt> : table of inlet names and their"
" path and typetag string, like <tt>{freq:['/something/freq','f']}</tt>\n\n"
"When the typetag string is a single letter, the inlet expects a single"
" value, otherwise it expects a vector with corresponding types.\n\n"
"<b>Type tags:</b>\n"
"- f : float\n"
"- i : 32 bit integer\n"
"- d : double\n"
"- c : 8 bit integer\n"
"- s : string\n"
"- S : symbol\n"
"- m : string of 4 midi bytes\n";
OscBus.init = func(o) {
    outbus.OutBus.init(o);
    o.parents = [OscBus];

    o.bus = playbus.create_oscbus();

    o.controllers = {
        foo:["/foo","f"],
    };

    o.add_obj_prop("controllers",nil,func {
        o.query_inlets();
        o.update();
    });

    o.osc_address = "osc.udp://localhost:7770";
    
    var addr_change = func {
        playbus.osc_set_addr(o.bus, o.osc_address);
        o.caption = o.osc_address;
        o.redraw();
    }
    o.add_obj_prop("osc_address",nil,addr_change,1);

    
    o.resolution = 0.02;
    o.add_obj_prop("resolution");

#    o.new_inlet("raw").keep=1;

    o.register_bus();    
    addr_change();
    o.query_inlets();
}
OscBus.query_inlets = func {

    foreach(var k;keys(me.inlets))
        me.inlets[k].delete_me=1;

    foreach(var name;keys(me.controllers)) {
        if(!contains(me.inlets,name))
            me.new_inlet(name);
        me.inlets[name].delete_me=0;
    }

    foreach(var k;keys(me.inlets)) {
        if(me.inlets[k].delete_me and me.inlets[k]["keep"]!=1)
            me.del_inlet(k);
    }
}
OscBus.generate = func {

    playbus.osc_clear_events(me.bus);

    foreach(var k;keys(me.controllers)) {
        var ev_cons = me.inlets[k].get_connections();
        var path = me.controllers[k][0];
        var fmt = me.controllers[k][1];

        foreach(var con;ev_cons) {
#            if(con.order==0) {
#                playbus.osc_add_event(me.bus,0,path,fmt,con.get_value(0));
#            }
            if(!con.get_interpolate()) {
                for(var i=0;i<con.datasize;i+=1) {
                    var ev = con.get_event(i);
                    playbus.osc_add_event(me.bus,ev[0],path,fmt,ev[1]);
                }
            } else {
                var last_val = nil;
                for(var t = con.start; t<con.start+con.length; t+=me.resolution) {
                    var val = con.get_value(t);
                    if(val!=last_val)
                        playbus.osc_add_event(me.bus,t,path,fmt,val);
                    last_val=val;
                }
            }
        }
    }
   
    playbus.osc_sort_events(me.bus);
    0;
}

EXPORT=["OscBus"];
