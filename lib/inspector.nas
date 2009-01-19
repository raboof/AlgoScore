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

# TODO:
# - better display of the stuff now in the TextView
# - show global variables deps and supplies
# - show links and/or groups
# - double click on a connection for its properties
# - is it possible to make the ScrolledWindow request default sizes
#   to fit their TreeViews?
# - is it possible to put each pane child in a GtkExpander so that it
#   gives the space to other childs when collapsed?

import("gtk");

var set_tree_lines = func(wid) {
    if(!gtk.check_version(2,10,0))
        wid.set("enable-tree-lines",1);
}

var w = gtk.Window("border-width",4);
#w.set("default-height",400,
w.set("default-width",600);
w.connect("delete-event",func w.hide());
var vbox = gtk.VBox("spacing",4);
w.add(vbox);
var pane = gtk.HPaned();

var top_pane = gtk.VPaned();
top_pane.add(pane);
vbox.pack_start(top_pane);

var text = gtk.TextView("name","monotext","editable",0,"cursor-visible",0);
#var sw = gtk.ScrolledWindow();
#sw.add(text);
#vbox.pack_start(sw,0);
#pane.add(sw);
pane.add(text);
pane.child_set(text,"resize",0,"shrink",1);

var vpane=gtk.VPaned();
pane.add(vpane);

inlet_store=gtk.tree_store_new("gchararray","gchararray","gchararray");
inlet_view=gtk.TreeView("model",inlet_store);
set_tree_lines(inlet_view);
col = gtk.TreeViewColumn("title","Inlet","resizable",1);
col.add_cell(gtk.CellRendererText(),0,"text",0);
inlet_view.append_column(col);
col = gtk.TreeViewColumn("title","Source obj","resizable",1);
col.add_cell(gtk.CellRendererText(),0,"text",1);
inlet_view.append_column(col);
col = gtk.TreeViewColumn("title","Outlet","resizable",1);
col.add_cell(gtk.CellRendererText(),0,"text",2);
inlet_view.append_column(col);
var sw = gtk.ScrolledWindow("height-request",100);
sw.add(inlet_view);
#vbox.pack_start(exp,0);
vpane.add(sw);

outlet_store=gtk.tree_store_new("gchararray","gchararray","gchararray","gchararray","gchararray");
outlet_view=gtk.TreeView("model",outlet_store);
set_tree_lines(outlet_view);
col = gtk.TreeViewColumn("title","Outlet","resizable",1);
col.add_cell(gtk.CellRendererText(),0,"text",0);
outlet_view.append_column(col);
col = gtk.TreeViewColumn("title","Dest obj","resizable",1);
col.add_cell(gtk.CellRendererText(),0,"text",1);
outlet_view.append_column(col);
col = gtk.TreeViewColumn("title","Inlet","resizable",1);
col.add_cell(gtk.CellRendererText(),0,"text",2);
outlet_view.append_column(col);
col = gtk.TreeViewColumn("title","resolution","resizable",1);
col.add_cell(gtk.CellRendererText(),0,"text",3);
outlet_view.append_column(col);
col = gtk.TreeViewColumn("title","interpolate","resizable",1);
col.add_cell(gtk.CellRendererText(),0,"text",4);
outlet_view.append_column(col);
var sw = gtk.ScrolledWindow("height-request",100);
sw.add(outlet_view);
#vbox.pack_start(exp,0);
vpane.add(sw);

class_store=gtk.tree_store_new("gchararray","gchararray","gchararray");
class_view=gtk.TreeView("model",class_store);
set_tree_lines(class_view);
col = gtk.TreeViewColumn("title","Class","resizable",1);
col.add_cell(gtk.CellRendererText(),0,"text",0);
class_view.append_column(col);
col = gtk.TreeViewColumn("title","Name","resizable",1);
col.add_cell(gtk.CellRendererText(),0,"text",1);
class_view.append_column(col);
col = gtk.TreeViewColumn("title","File","resizable",1);
col.add_cell(gtk.CellRendererText(),0,"text",2);
class_view.append_column(col);
var sw = gtk.ScrolledWindow("height-request",100);
sw.add(class_view);
#vbox.pack_start(sw);
#var exp = gtk.Expander("label","Class hierarchy");
#exp.add(sw);
top_pane.add(sw);

#vpane.connect("configure-event",func(wid) {
#    wid.set("position",wid.get("max-position")/2,"position-set",1);
#});

var bbox = gtk.HButtonBox("layout-style","end","spacing",4);
vbox.pack_start(bbox,0);

var b = gtk.Button("label","gtk-refresh","use-stock",1,"use-underline",1);
b.connect("clicked",func update());
bbox.add(b);

var b = gtk.Button("label","gtk-close","use-stock",1,"use-underline",1);
b.connect("clicked",func w.hide());
bbox.add(b);

#var add_class_hier_old = func(s,obj) {
#    s ~= "\nClass hierarchy:\n";
#    var lev=0;
#    var _get_par = func(o) {
#        if(!contains(o,"parents")) return;
#        foreach(p;o.parents)
#            _get_par(p);
#        lev += 1;
#        foreach(p;o.parents) {
#            var pad = "";
#            for(i=2;i<lev;i+=1)
#                pad ~= "  ";
#            if(lev>1) {
#                s ~= pad ~ "|\n";
#                s ~= pad ~ "`-";
#            }
#            s ~= p.source_name;
#            s ~= sprintf(" [%s] (%s/%s)\n",
#                p['name'] or "",
#                p['class_dir'] or "?",
#                p['class_file'] or "?");
#        }
#    }
#    _get_par(obj);
#}

var get_class_hier = func(obj) {
    class_store.clear();
    var _get_par = func(o) {
        if(!contains(o,"parents")) return nil;
        foreach(p;o.parents) {
            var row = _get_par(p);
            class_store.set_row(row=class_store.append(row),
                0,p['source_name'] or "?",
                1,p['name'] or "",
                2,sprintf("%s/%s",
                    p['class_dir'] or "?",
                    p['class_file'] or "?")
            );
        }
        return row;
    }
    _get_par(obj);
    class_view.expand_all();
}

var get_inlets = func(obj) {
    inlet_store.clear();
    foreach(k;keys(obj.inlets)) {
        var in = obj.inlets[k];
        inlet_store.set_row(var top=inlet_store.append(),0,k);
        foreach(c;in.get_connections()) {
            inlet_store.set_row(inlet_store.append(top),1,
                c.srcobj.get_label(),2,c.outlet);
        }
    }
    inlet_view.expand_all();
}

var get_outlets = func(obj) {
    outlet_store.clear();
    foreach(var k1;keys(obj.outlets)) {
        var out = obj.outlets[k1];
        outlet_store.set_row(var top=outlet_store.append(),0,k1,3,out.resolution,4,out.interpolate);
        foreach(k;keys(obj.children)) {
            var child = obj.children[k];
            foreach(k;keys(child.inlets)) {
                var in = child.inlets[k];
                foreach(c;in.get_connections()) {
                    if(c.srcobj==obj and c.outlet==k1) {
                        outlet_store.set_row(outlet_store.append(top),1,
                            child.get_label(),2,k);
                    }
                }
            }
        }
    }
    outlet_view.expand_all();
}

var last_obj=nil;
var update = func(obj=nil) {
    if(obj==nil) obj=last_obj;
    if(obj==nil) return;
    last_obj=obj;
    var buf = text.get("buffer");
    var s = sprintf("id:\t%s\nclass:\t%s\ncaption: '%s'\nsticky: %d\nfixed_start: %d\nghost: %d\n",
        obj.id,obj.name,obj.caption,obj.sticky,obj.fixed_start,obj.is_ghost);

    s ~= "\nDependencies:\n";
    var l = obj.get_parents();
    foreach(k;keys(l)) {
        var o = l[k];
        s ~= sprintf("- %s\n",o.get_label());
    }
    s ~= "\nDependants:\n";
    var l = obj.children;
    foreach(k;keys(l)) {
        var o = l[k];
        s ~= sprintf("- %s\n",o.get_label());
    }
    
    buf.set("text",s);
    get_class_hier(obj);
    get_inlets(obj);
    get_outlets(obj);
}

var inspect = func(obj) {
    if(obj==nil) return;
    w.set("title","Inspect: "~obj.get_label());
    update(obj);
    w.show_all();
    w.raise();
#    sw.check_resize();
}

EXPORT=["inspect"];
