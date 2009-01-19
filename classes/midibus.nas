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

MidiBus = {name:"midi_bus",parents:[outbus.OutBus]};
MidiBus.description =
"<b>Output MIDI to JACK or midifile.</b>\n\n"
"<b>Properties:</b>\n"
"- <tt>port_id</tt> : name of the JACK midiport.\n"
"- <tt>channel</tt> : MIDI channel.\n"
"- <tt>controllers</tt> : table of CC names and their"
" number, like <tt>{mod:1,vol:7}</tt>. Add 1000 to the number"
" to make it send 14 bit controllers instead of 7 bit.\n"
"- <tt>resolution</tt> : resolution of interpolated inputs.\n\n"
"<b>Inputs:</b>\n"
"- <tt>note</tt> : note events in the format <tt>[pitch, velocity]</tt> or"
" <tt>[pitch, velocity, duration]</tt>.\n"
"- <tt>pitch</tt> : numerical input in the range -1.0 to +1.0 for pitchwheel events.\n"
"- <tt>raw</tt> : events of raw midi bytes, like <tt>[0x90, 60, 100]</tt>.\n"
"All CC's defined in <tt>controllers</tt> shows up as inputs, and takes numerical"
" data in the range 0.0 to 1.0.\n";
MidiBus.init = func(o) {
    outbus.OutBus.init(o);
    o.parents = [MidiBus];

    o.bus = playbus.create_midibus();
    o.port_id = "midi_"~o.id;
    o.channel = 1;
    
    var port_change = func {
        playbus.set_midiport(o.bus, o.port_id);
        o.caption = o.port_id;
#        o.update_entry();
        o.redraw();
    }
    o.add_obj_prop("port_id",nil,port_change,1);
    o.add_obj_prop("channel");
    
    o.controllers = {mod:1,breath:2,foot:4,vol:7,bal:8,pan:10,exp:11,fx1:12,fx2:13};
    o.add_obj_prop("controllers",nil,func {
        o.query_inlets();
        o.update();
    });
    
    o.resolution = 0.05; #50 ms
    o.add_obj_prop("resolution");

    o.new_inlet("note").keep=1;
    o.new_inlet("pitch").keep=1;
    o.new_inlet("raw").keep=1;

    o.register_bus();    
    port_change();
}
MidiBus.query_inlets = func {

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
MidiBus.generate = func {

    playbus.clear_events(me.bus);

    var buf = bits.buf(3);

    var scale_pitch = func(x) int((x+1)*8192);
    var scale_ctrl = func(x) int(x*127);
        
    var put_ctrl = func(t, chan, parm, val) {
        if(parm>1000) {
            put_ctrl(t, chan, parm-1000, playbus.msb14(val));
            put_ctrl(t, chan, parm-1000+32, playbus.lsb14(val));
            return;
        }
        buf[0] = 0x0B0 + chan;
        buf[1] = parm;
        buf[2] = val;
        playbus.add_event(me.bus,t,buf);
    }
    var put_pitch = func(t, chan, val) {
        buf[0] = 0x0E0 + me.channel-1;
        buf[1] = playbus.lsb14(val);
        buf[2] = playbus.msb14(val);
        playbus.add_event(me.bus,t,buf);
    }

    var ev_cons = me.inlets.note.get_connections();
    foreach(var con;ev_cons) {
        for(var i=0;i<con.datasize;i+=1) {
            var ev = con.get_event(i);
            var t = ev[0];
            if(t>con.start+con.length) break;
            buf[0] = 0x090 + me.channel-1;
            buf[1] = ev[1][0];
            buf[2] = ev[1][1];
            playbus.add_event(me.bus,t,buf);
            if(size(ev[1])>2) {
                buf[2]=0;
                playbus.add_event(me.bus,t+ev[1][2],buf);
            }
        }
    }
      
    foreach(var k;keys(me.inlets)) {
        if(!contains(me.controllers,k)) continue;
    
        var ev_cons = me.inlets[k].get_connections();
        var cc = me.controllers[k];

        foreach(var con;ev_cons) {
            if(con.order==0) {
                put_ctrl(0,me.channel-1,cc,scale_ctrl(con.get_value(0)));
            }
            if(!con.get_interpolate()) {
                for(var i=0;i<con.datasize;i+=1) {
                    var ev = con.get_event(i);
                    put_ctrl(ev[0],me.channel-1,cc,scale_ctrl(ev[1]));
                }
            } else {
                var last_val = nil;
                for(var t = con.start; t<con.start+con.length; t+=me.resolution) {
                    var val = scale_ctrl(con.get_value(t));
                    if(val!=last_val) put_ctrl(t,me.channel-1,cc,val);
                    last_val=val;
                }
            }
        }
        
    }

    var ev_cons = me.inlets.pitch.get_connections();
    
    foreach(var con;ev_cons) {
        if(con.order==0) {
            put_pitch(0,me.channel-1,scale_pitch(con.get_value(0)));
        }
        if(!con.get_interpolate()) {
            for(var i=0;i<con.datasize;i+=1) {
                var ev = con.get_event(i);
                put_pitch(ev[0],me.channel-1,scale_pitch(ev[1]));
            }
        } else {
            var last_val = nil;
            for(var t = con.start; t<con.start+con.length; t+=me.resolution) {
                var val = scale_pitch(con.get_value(t));
                if(val!=last_val) put_pitch(t,me.channel-1,val);
                last_val=val;
            }
        }
    }

    var ev_cons = me.inlets.raw.get_connections();
    foreach(var con;ev_cons) {
        for(var i=0;i<con.datasize;i+=1) {
            var ev = con.get_event(i);
            var t = ev[0];
            if(t>con.start+con.length) break;
            var buf = bits.buf(size(ev[1]));
            forindex(var x;ev[1])
                buf[x]=ev[1][x];
            playbus.add_event(me.bus,t,buf);
        }
    }
   
    playbus.sort_events(me.bus);
    0;
}

EXPORT=["MidiBus"];
