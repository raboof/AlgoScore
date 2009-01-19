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
import("options");
import("debug");

var w = gtk.Window("title","AlgoScore preferences","border-width",4);
w.set("default-height",400,"default-width",600);
w.connect("delete-event",func w.hide());

var store = gtk.ListStore_new("gchararray","gchararray","gchararray");

var edit_value = func(wid,row,val) {
    if(val!=store.get_row(row,1)) {
        var code = compile(val);
        var val2 = code();
        options.set(opts[row],val2);
#        store.set_row(row,1,val);
        update();
    }
}

var view = gtk.TreeView("model",store);
var col = gtk.TreeViewColumn("title","Name","expand",1);
col.add_cell(gtk.CellRendererText(),0,"text",0);
view.append_column(col);
var col = gtk.TreeViewColumn("title","Value");
col.add_cell(var cell = gtk.CellRendererText("editable",1),0,"text",1);
view.append_column(col);
cell.connect("edited",edit_value);
var col = gtk.TreeViewColumn("title","Default");
col.add_cell(gtk.CellRendererText(),0,"text",2);
view.append_column(col);

var sw = gtk.ScrolledWindow();
sw.add(view);
var vbox = gtk.VBox("spacing",4);
vbox.pack_start(sw);
var bbox = gtk.HButtonBox("layout-style","end","spacing",4);
vbox.pack_start(bbox,0);
w.add(vbox);

var set_default = func {
    var row = view.get_selection().get_selected();
    var opt = opts[row];
    options.set(opt,options.get_default(opt));
    update();
}

var tips = gtk.Tooltips();

foreach(var btn;[
    ["set default",set_default,"Set selected value to default"],
    ["gtk-revert-to-saved", func { options.load(); update();},"Revert to last saved settings"],
    ["gtk-save", func options.save(),"Save settings"], 
    ["gtk-close", func w.hide(),"Close this window"],
]) {
    var b = gtk.Button("label",btn[0],"use-stock",1,"use-underline",1);
    b.connect("clicked",btn[1]);
    bbox.add(b);
    tips.set_tip(b,btn[2]);
}

var opts = nil;

var update = func {
    var row = view.get_selection().get_selected();
    opts = options.list();
    store.clear();
    foreach(var o;opts) {
        store.set_row(store.append(),
            0,o,
            1,debug.dump(options.get(o)),
            2,debug.dump(options.get_default(o)));
    }
    if(row!=nil) view.get_selection().select(row);
}

var show = func {
    update();
    w.show_all();
}

EXPORT=['show'];
