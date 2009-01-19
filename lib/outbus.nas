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
import("winreg");
import("gtk");
import("playbus");
import("sndfile");
import("debug");
import("optbox");
import("unix");
import("utils");

var busses = {};

#var update_buslist = func {
#    store.clear();
#    foreach(var v;keys(busses)) {
#        var bus = busses[v];
#        bus._row = store.append();
#        update_entry(bus);
#    }
#}

var unregister_bus = func(o) {
    delete(busses,int(o.id));
#    update_buslist();
}

var register_bus = func(o) {
    busses[int(o.id)]=o;
#    update_buslist();
}

#var update_entry = func(bus) {
#    if(bus._row==nil) return;
#    forindex(var i;busprops) {
#        store.set_row(bus._row, i,
#            algoscore.find_sym(bus,busprops[i]));
##            bus.get_prop(busprops[i]));
#    }
#}

#var export_toggled = func(wid,row) {
#    var id = int(store.get_row(row,0));
#    var bus = busses[id];
#    bus.set_prop("export_enable",!bus.export_enable);
#}

#var make_prop_handler = func(n) {
#    var prop = busprops[n];
#    return func(wid,row,val) {
#        var bus = busses[int(store.get_row(row,0))];
##        bus.properties[prop].set(val);
#        bus.set_prop(prop,val);
#    }
#}

#var busprops = [
#    "id",
##    "caption",
#    "export_file",
#    "export_enable",
#    "port_id",
#    "channels",
#];

#var store = gtk.ListStore_new(
#    "gchararray", # 0 - id
##    "gchararray", # 1 - caption
#    "gchararray", # 2 - export file
#    "gboolean",   # 3 - export enable
#    "gchararray", # 4 - jack port
#    "gchararray", # 5 - channels
#);
#var view = gtk.TreeView("model",store);

#var c = gtk.TreeViewColumn("title","id","resizable",1);
#c.add_cell(var cell=gtk.CellRendererText(),0,"text",0);
#view.append_column(c);

#var c = gtk.TreeViewColumn("title","port","resizable",1);
#c.add_cell(var cell = gtk.CellRendererText("editable",1),0,"text",3);
#cell.connect("edited",make_prop_handler(3));
#view.append_column(c);

#var c = gtk.TreeViewColumn("title","channels","resizable",1);
#c.add_cell(var cell = gtk.CellRendererText("editable",1),0,"text",4);
#cell.connect("edited",make_prop_handler(4));
#view.append_column(c);

#var c = gtk.TreeViewColumn("title","export file","resizable",1);
#c.add_cell(var cell = gtk.CellRendererText("editable",1),0,"text",1);
#cell.connect("edited",make_prop_handler(1));
#view.append_column(c);

#var c = gtk.TreeViewColumn("title","export enable","resizable",1);
#c.add_cell(var cell = gtk.CellRendererToggle(),0,"active",2);
#cell.connect("toggled",export_toggled);
#view.append_column(c);

#var w = gtk.Window("title","Output busses","default-height",500,"default-width",700);
#w.connect("delete-event",func w.hide());

#var sc = gtk.ScrolledWindow("hscrollbar-policy","never");
#sc.add(view);
#w.add(sc);

#winreg.add_window("Output busses",w,"<Alt>o");


OutBus = {source_name:"OutBus",parents:[algoscore.ASObject]};
#OutBus.name = "test_out";
OutBus.init = func(o) {
    playbus.init();
    algoscore.ASObject.init(o);
    o.parents=[OutBus];
    o.height=10;
    o.sticky=1;
    o.start=0;
    o.fixed_start=1;
    #FIXME! either ignore length if sticky is set, or auto-set it
    #to 'end' mark...
#    o.length=31536000; # one year should be enough... ;)
    o.length=0;

#    o.caption=o.name~o.id;
#    o._row = nil;
#    o.export_enable = 1;
#    o.export_file = "";
#    o.port_id = o.name~o.id;
#    var f = func {
#        o.update_entry();
#        o.redraw();
#    }
#    o.add_obj_prop("export_enable",nil,f,1);
#    o.add_obj_prop("export_file",nil,f,1);

    o.del_obj_prop("length");
    o.del_obj_prop("start");
    o.del_obj_prop("height");

#    if(!playbus_initialized) {
#        playbus.init();
#        playbus_initialized=1;
#    }
}
#OutBus.update_entry = func update_entry(me);
OutBus.register_bus = func register_bus(me);
OutBus.cleanup = func {
    print("removing bus ",me.caption,"\n");
    unregister_bus(me);
    playbus.remove_bus(me.bus);
}
#OutBus.edit_start = func {
#    w.show_all();
#    w.raise();
#    return 0;
#}
OutBus.draw = func(cr) {
    cairo.set_line_width(cr,2);
    cairo.move_to(cr,0,me.height/2);
    cairo.rel_line_to(cr,me.width-2,0);
    cairo.stroke(cr);
    cairo.move_to(cr,me.width-2,me.height/2);
    cairo.rel_line_to(cr,-8,-3);
    cairo.rel_line_to(cr,0,6);
    cairo.close_path(cr);
    cairo.stroke_preserve(cr);
    cairo.fill(cr);
}
# perhaps put canvas_w and end mark in score object,
# then we can make the arrow stop at the end mark, etc...
OutBus.update_geometry = func(cr,canvas_w) {
#    print("update_geom: ",canvas_w,"\n");
    me.width = canvas_w;
}
#OutBus.cancel_generate = func nil; #moved to ASObject
OutBus.reconnect = func nil;

var cancel_all = func {
    foreach(var k;keys(busses)) {
        var bus = busses[k];
        bus.cancel_generate();
    }
}

var reconnect_all = func {
    foreach(var k;keys(busses)) {
        var bus = busses[k];
        bus.reconnect();
    }
}

#playbus.init();

var fmts = sndfile.list_formats();
var major_formats = keys(fmts);
var major_formats_labels = [];
foreach(var f;major_formats)
    append(major_formats_labels,fmts[f][0]);

var upd_encodings = func(o,fmt) {
    var sub = fmts[fmt][2];
    var encodings = keys(sub);
    var encodings_labels = [];
    foreach(f;encodings)
        append(encodings_labels,sub[f]);
    o.choices = encodings;
    o.choices_labels = encodings_labels;
    if(o["update"]!=nil) {
        o.update();
        o.set(0x02);
    }
}

var opts = {};

var set_file_ext = func {
    var bus = optbox.get_value(opts.bus);
    if(ghosttype(bus.bus)=="MidiBus") ext="mid";
    else ext = fmts[optbox.get_value(opts.format)][1];
    var fn = optbox.get_value(opts.file);
    var s = split(".",fn);
    s[-1]=ext;
    fn=s[0];
    for(var i=1;i<size(s);i+=1)
        fn~="."~s[i];
    opts.file.set(fn);
}

var set_widget_sens = func(bus) {
    var x = ghosttype(bus)=="AudioBus";
#    print("widget sens: ",ghosttype(bus),"\n");
    opts.normalize.enable(x);
    opts.format.enable(x);
    opts.encoding.enable(x);

    opts.tpqn.enable(!x);
    opts.spqn.enable(!x);
}

var audio_export_opts = [
    { name:"bus", label:"Bus", type:"combobox", value:"",
      callback:func(o,opts) {
        set_widget_sens(o.new_value.bus);
        set_file_ext();
      }
    },
    { name:"file", label:"Export to file:", type:"filechooser",
      value:unix.getcwd()~"/export.xxx", action:"save"},
    { name:"normalize",label:"Normalize",type:"toggle",value:1},
    { name:"format", label:"File format", type:"combobox",
      choices:major_formats,
      choices_labels:major_formats_labels,
      value:0x010000,
      callback:func(o,opts) {
        set_file_ext();
        upd_encodings(opts.encoding,o.new_value);
      },
    },
    { name:"encoding", label:"Encoding", type:"combobox", choices:[], value:0x02 },
    { name:"tpqn", label:"Ticks per beat", type:"entry", value:384 },
    { name:"spqn", label:"Seconds per beat", type:"entry", value:0.5 },
    { name:"progress", label:"Progress", type:"progress", value:0 },
];

foreach(var o;audio_export_opts) opts[o.name]=o;

var export_bus = func {
    if(!size(busses)) {
        utils.msg_dialog("Error","No exportable busses in this score","warning");
        return;
    }
    var list = [];
    var list_labels = [];
    foreach(var b;keys(busses)) {
        if(ghosttype(busses[b].bus)=="OSCBus") continue;
        var lbl = busses[b].get_label();
        var cap = busses[b].caption;
        if(cap) lbl ~= " ("~cap~")";
        append(list_labels,lbl);
        append(list,busses[b]);
    }

    opts.bus.choices = list;
    opts.bus.choices_labels = list_labels;
    opts.bus.value = size(list)>0?list[0]:"";
        
    optbox.open("Export bus",audio_export_opts,func(x) {
        if(x==nil) return;
        var values = optbox.value_hash(x);
        print("exporting to file ",values.file,"\n");
        if(ghosttype(values.bus.bus)=="AudioBus") {
            var et = values.bus.score.endmark.time;
            playbus.export_audio(values.bus.bus,values.file,values.format+values.encoding,values.normalize,func(t) {
                x.progress.set(t/et);
                gtk.main_iterate_while_events();
                return 1;
            });
        } else {
            playbus.export_midi(values.bus.bus,values.file,values.tpqn,values.spqn);
        }

        return 0;
    });

    upd_encodings(opts.encoding,0x010000);
    set_widget_sens(opts.bus.value.bus);
    set_file_ext();
}

EXPORT = ["OutBus","cancel_all","export_bus","reconnect_all"];
