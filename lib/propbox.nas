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

import("gtk");
import("debug");
import("winreg");
import("globals","*");

var namespace = nil;
var opts = nil;
var w = gtk.Window("border-width",4,"transient-for",globals.top_window);
w.set("default-height",400,"default-width",400);
w.connect("delete-event",func w.hide());
var store = gtk.ListStore_new("gchararray","gchararray");

var edit_value = func(wid,row,val) {
    if(val!=store.get_row(row,1)) {
        var prop = store.get_row(row,0);
        var x = opts[prop];
        if(x["no_eval"]!=1) {
            var code = compile(val);
#            var val = code();
            if(namespace==nil) namespace = new_nasal_env();
            var val = call(code,nil,nil,namespace);
        }
        x.set(val);
        update();
    }
}

var update = func {
    var row = view.get_selection().get_selected();
    store.clear();
    foreach(var k;sort(keys(opts),cmp)) {
        if(opts[k]["no_edit"]==1)
            continue;
        var r = store.append();
        var v = opts[k].get();
        if(opts[k]["no_eval"]!=1)
            v = debug.dump(v);
        store.set_row(r,0,k,1,v);
        opts[k].row=r;
    }
    if(row!=nil) view.get_selection().select(row);
}

var view = gtk.TreeView("model",store);
var col = gtk.TreeViewColumn("title","Name","expand",1,"resizable",1);
col.add_cell(gtk.CellRendererText(),0,"text",0);
view.append_column(col);
var col = gtk.TreeViewColumn("title","Value","resizable",1);
col.add_cell(var cell = gtk.CellRendererText("editable",1),0,"text",1);
view.append_column(col);
cell.connect("edited",edit_value);

var sw = gtk.ScrolledWindow();
sw.add(view);
var vbox = gtk.VBox("spacing",4);
vbox.pack_start(sw);
var bbox = gtk.HButtonBox("layout-style","end","spacing",4);
vbox.pack_start(bbox,0);
w.add(vbox);

var b = gtk.Button("label","gtk-refresh","use-stock",1,"use-underline",1);
b.connect("clicked",update);
bbox.add(b);

var b = gtk.Button("label","gtk-close","use-stock",1,"use-underline",1);
#    b.connect("clicked",func { w.hide(); w.destroy()});
b.connect("clicked",func w.hide());
bbox.add(b);
    
var edit_props = func(title,opts2,ns=nil) {
    opts=opts2;
    namespace=ns;
    w.set("title",title~" properties");
#    var w = gtk.Window("title",title~" properties","border-width",4);
#    w.set("default-height",400,"default-width",400);
#    w.connect("delete-event",func { w.hide(); w.destroy()});
#    var store = gtk.ListStore_new("gchararray","gchararray");
    update();
    w.show_all();
    w.raise();
}

winreg.add_window("Object properties",w);

#var set_topwindow = func(tw) w.set("transient-for",tw);

EXPORT=['edit_props'];
