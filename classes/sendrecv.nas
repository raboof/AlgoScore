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

var sends = {};
var recvs = {};

var last_sym = `A`-1;

var bus_draw = func(cr,ofs,width,last) {
    cairo.set_line_width(cr,2);
    cairo.move_to(cr,0,me.height/2);
    cairo.rel_line_to(cr,width,0);
    if(last) {
        cairo.rel_move_to(cr,0,-me.height/2);
        cairo.rel_line_to(cr,0,me.height);
    }
    cairo.stroke(cr);
}

SendObj = {name:"send",parents:[algoscore.ASObject]};
SendObj.description = "Send data to all Recv objects that are listening on the same symbol.";
SendObj.init = func(o) {
    algoscore.ASObject.init(o);
    o.parents=[SendObj];
    o.height = 10;
    o.new_inlet("in");
    o.old_symbol = nil;
    last_sym += 1;
    o.symbol = chr(last_sym);
    o.add_obj_prop("symbol",nil,func o.change_sym(),1);
    o.change_sym();
}
SendObj.change_sym = func {
    sends[me.symbol] = me;
    if(me.old_symbol!=nil) {
        delete(sends,me.old_symbol);
        foreach(var k;keys(recvs)) {
            if(k==me.old_symbol) recvs[k].update();
        }
    }
    me.old_symbol = me.symbol;
    me.caption = "S:"~me.symbol;
    me.generate();
}
SendObj.draw = bus_draw;
SendObj.cleanup = func {
    delete(sends,me.symbol);
}
SendObj.generate = func {
    foreach(var k;keys(recvs)) {
        if(k==me.symbol) recvs[k].update();
    }
    0;
}

RecvObj = {name:"recv",parents:[algoscore.ASObject]};
RecvObj.description = "Receive data from the Send object that are sending on the same symbol.";
RecvObj.init = func(o) {
    algoscore.ASObject.init(o);
    o.parents=[RecvObj];
    o.height = 10;
    o.new_outlet("out");
#    var k = keys(sends);
    o.old_symbol = nil;
    o.symbol = chr(last_sym);#size(k)?k[0]:"A";
    o.add_obj_prop("symbol",nil,func o.change_sym(),1);
    o.change_sym(o.id);
}
RecvObj.change_sym = func {
    if(me.old_symbol!=nil) delete(recvs,me.old_symbol);
    recvs[me.symbol] = me;
    me.old_symbol = me.symbol;
    me.caption = "R:"~me.symbol;
    me.update();
}
RecvObj.get_value = func(outlet, t) {
    var send = sends[me.symbol];
    if(send==nil) return 0;

    var get = send.inlets["in"].val_finder(0);
    return get(t);
}
RecvObj.get_event = func(outlet, n) {
    var send = sends[me.symbol];
    if(send==nil) return 0;
    var in = send.inlets["in"];
    var cons = in.get_connections();
    if(n>=in.datasize) n=in.datasize-1;
    var j=0;
    foreach(var con;cons) {
        for(var i=0;i<con.datasize;i+=1) {
            if(j==n)
                return con.get_event(i);
            j += 1;
        }
    }
    return [0,0];
}
RecvObj.get_datasize = func(outlet) {
    var send = sends[me.symbol];
    if(send==nil) return 0;
    return send.inlets["in"].datasize;
}
RecvObj.draw = bus_draw;
RecvObj.cleanup = func {
    delete(recvs,me.symbol);
}


EXPORT = ["SendObj","RecvObj"];
