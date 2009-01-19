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
import("outbus");
import("playbus");
import("math");
import("cairo");

# TODO
# for regions: also con.length and file ofs if any.
# and channels, in case one wants to use only individual channels of file?
# also create temporary audiofile if the connections doesn't have any,
# and use get_value(t) to get each sample...

#deprecated..
#make a soundfile bus that simply plays a soundfile.

AudioBus = {name:"audio_bus",parents:[outbus.OutBus]};
AudioBus.description =
"<b>Output audio to JACK or soundfile.</b>\n\n"
"<tt>port_id</tt> property sets the prefix of the JACK ports.\n"
"<tt>channels</tt> property sets number of ports.\n"
"Input is special connections with <tt>audiobuf</tt> variable set.";
AudioBus.init = func(o) {
    outbus.OutBus.init(o);
    o.parents = [AudioBus];

    o.port_id = "audio_"~o.id;
    o.channels=1;

    o.bus = playbus.create_bus();
#    o.bus = nil;

    var port_change = func {
        o.channels = int(o.channels);
        if(o.channels==nil) o.channels=1;
        playbus.setup_ports(o.bus, o.port_id, o.channels);
        o.caption = o.port_id;
#        o.update_entry();
        o.redraw();
    }

#    o.add_obj_prop("caption",nil,f,1);
    o.add_obj_prop("port_id",nil,port_change,1);
    o.add_obj_prop("channels",nil,port_change,1);
#    o.add_obj_prop("amp",nil,func {
#        playbus.set_amp(o.bus,o.amp);
#    });
    
    o.amp = 1;
    o.add_obj_prop("amp",nil,func {
        playbus.set_amp(o.bus,o.amp);
    });
    o.new_inlet("in");

    o.register_bus();
    port_change();
}
AudioBus.generate = func {
    var regions = [];
    var cons = me.inlets.in.get_connections();
    foreach(var con;cons) {
        append(regions,[con.audiobuf,con.start]);
    }
    playbus.set_regions(me.bus,regions);
    0;
}

SndFile = {name:"sndfile",parents:[algoscore.ASObject]};
SndFile.description = "<b>read soundfile</b>, connects to audio_bus";
SndFile.init = func(o) {
    algoscore.ASObject.init(o);
    o.parents=[SndFile];
    o.height=10;
    o.sndfile="";
    o.add_obj_prop("sndfile",nil,func {
        o.caption=o.sndfile;
        o.update();
    },1);
    o.new_outlet("out");
}
SndFile.generate = func {
    me.outlets.out.audiobuf = me.sndfile;
    0;
}
SndFile.draw = func(cr,ofs,width,last) {
    cairo.set_line_width(cr,1);
    cairo.translate(cr,0.5,0.5);
    var r = me.height/2;
    
    if(ofs==0) {
        cairo.new_path(cr);
        cairo.arc(cr,r,r,r-1,0,2*math.pi);
        cairo.stroke(cr);
        cairo.arc(cr,r*3,r,r-1,0,2*math.pi);
        cairo.stroke(cr);
        cairo.move_to(cr,r,me.height-1);
        cairo.rel_line_to(cr,r*2,0);
        cairo.stroke(cr);
    }
    
    cairo.move_to(cr,r*4,r);
    cairo.line_to(cr,width,r);
    if(last) {
        cairo.rel_move_to(cr,0,-r);
        cairo.rel_line_to(cr,0,me.height);
    }
    cairo.stroke(cr);
}

#EXPORT=["SndFile"];
