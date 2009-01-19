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

# custom additional buttons which works like OK
# (for things like "preview")

# TODO:
# colorbutton
# fontbutton
# multiline text

var set_def = func(opt,field,val) {
    if(!contains(opt,field)) opt[field]=val;
}

var mk_lbl = func(lbl,szgrp) {
    var l = gtk.Label("label",lbl,"xalign",1);
    szgrp.add_widget(l);
    return l;
}

var mk_lbox = func(lbl,szgrp,wid=nil) {
    var box = gtk.HBox("spacing",4);
    box.pack_start(mk_lbl(lbl,szgrp),0);
    if(wid!=nil) box.pack_start(wid);
    return box;
}

var _widget = {};
_widget.entry = func(opt,szgrp,opts) {
    var ent = gtk.Entry("text",opt.value);
    var box = mk_lbox(opt.label,szgrp,ent);
    ent.connect("changed",func {
        opt.new_value = ent.get("text");
    });
    opt.enable = func(x) ent.set("sensitive",x);
    return box;
}
_widget.progress = func(opt,szgrp,opts) {
    var p = gtk.ProgressBar("fraction",opt.value);
    var box = mk_lbox(opt.label,szgrp,p);
    opt.set = func(val) p.set("fraction",val);
    return box;
}
_widget.toggle = func(opt,szgrp,opts) {
    var t = gtk.CheckButton("active",opt.value);#,"label",opt.label);
    var box = mk_lbox(opt.label,szgrp,t);
    t.connect("toggled",func {
        opt.new_value = t.get("active");
        if(opt['callback']!=nil) opt.callback(opt,opts);
    });
    opt.set = func(val) {
        t.set("active",val);
    }
    opt.enable = func(x) t.set("sensitive",x);
    return box;
}
_widget.spinbutton = func(opt,szgrp,opts) {
    var ent = gtk.SpinButton();
    var box = mk_lbox(opt.label,szgrp,ent);
    adj = ent.get("adjustment");
    set_def(opt,"max",999999);
    set_def(opt,"min",0);
    set_def(opt,"step",1);
    set_def(opt,"digits",0);
    ent.set("digits",opt.digits,"numeric",1);
    adj.set("upper",opt.max,"lower",opt.min,"step-increment",opt.step);
    adj.set("value",opt.value);
    adj.connect("value-changed",func {
        opt.new_value = adj.get("value");
        if(opt['callback']!=nil) opt.callback(opt,opts);
    });
    opt.set = func(val) {
        adj.set("value",val);
    }
    opt.enable = func(x) {
        ent.set("sensitive",x);
    }
    return box;
}
_widget.combobox = func(opt,szgrp,opts) {
    var list = gtk.ListStore_new("gchararray");
    var f = 0;
    opt.update = func {
        list.clear();
        var choices = opt["choices_labels"];
        if(choices==nil) choices=opt.choices;
        forindex(var i; choices) {
            var v = choices[i];
            list.set_row(var r = list.append(),0,v);
            if(opt.choices[i]==opt.value) f = r;
        }
    }
    opt.update();
    var combo = gtk.ComboBox("model",list,"active",f);
    combo.add_cell(gtk.CellRendererText(),1,"text",0);
    var change_cb = func {
        var r = num(combo.get("active"));
        if(r!=nil) {
            opt.new_value = opt.choices[r];
            if(opt['callback']!=nil) opt.callback(opt,opts);
        }
    }
    combo.connect("changed",change_cb);
#    if(opt["init_callback"]==1) change_cb();
    opt.set = func(val) {
        forindex(var i;opt.choices) {
            if(opt.choices[i]==val) break;
        }
        combo.set("active",i);
    }
    opt.enable = func(x) combo.set("sensitive",x);
    return mk_lbox(opt.label,szgrp,combo);
}
_widget.filechooser = func(opt,szgrp,opts) {
    set_def(opt,"action","open");
    set_def(opt,"value","");
    var box = gtk.HBox("spacing",5);
    var lbl = gtk.Label("label",opt.value,"ellipsize","start");
    box.pack_start(lbl);
    var btn = gtk.Button("image",gtk.Image("stock","gtk-" ~ opt.action));
    box.pack_start(btn,0);
    var cb = func {
        var fc = gtk.FileChooserDialog("title",opt.label,"action",opt.action);
        if(contains(opt,"new_value")) {
            var val = opt.new_value;
        } else {
            var val = opt.value;
        }
        if(val!="") {
            fc.set_current_name(val);
        }
        fc.set_current_name(val);
        fc.add_buttons("gtk-cancel",-2,"gtk-ok",-3);
        fc.connect("response",func(wid,id) {
            if(id==-3) {
                var fn = fc.get_filename();
                if(fn!=nil) {
                    opt.new_value = fn;
                    lbl.set("label",opt.new_value);
                    if(opt['callback']!=nil) opt.callback(opt,opts);
                }
                fc.hide();
                fc.destroy();
            } elsif(id==-2) {
                fc.hide();
                fc.destroy();
            }
        });

        fc.show_all();
    }
    opt.set = func(val) {
        opt.new_value = val;
        lbl.set("label",val);
    }
    btn.connect("clicked",cb);
    return mk_lbox(opt.label,szgrp,box);
}

var open = func(title,opts,cb=nil,buts=nil) {
    var w = gtk.Window("title",title,"width-request",300);
    
    var notebook = gtk.Notebook("scrollable",1);
    var groups = {};
    var szgroups = {};
    foreach(var o;opts) {
        if(!contains(o,"group")) o.group="options";
        var g = o.group;
        if(!contains(groups,g)) {
            var box = gtk.VBox("border-width",5,"spacing",2);
            groups[g] = box;
            szgroups[g] = gtk.SizeGroup("mode","horizontal");
            notebook.add(box);
            notebook.child_set(box,"tab-label",g);
        }
    }
    
    var vbox = gtk.VBox("border-width",5,"spacing",2);
    vbox.pack_start(notebook);
  
    var ret={};

    var ok = gtk.Button("label","gtk-ok","use-stock",1);
    var ca = gtk.Button("label","gtk-cancel","use-stock",1);
    var bb = gtk.HButtonBox("layout-style","spread");
    
    if(buts!=nil) foreach(var b;buts) bb.add(b);
    
    bb.add(ca);
    bb.add(ok);
    vbox.pack_end(bb);
    vbox.pack_end(gtk.HSeparator(),0,0,3);
    w.add(vbox);
    var canc = func { w.hide(); w.destroy(); if(cb!=nil) cb(nil); }
    w.connect("delete-event",canc);
    ca.connect("clicked",canc);
    ok.connect("clicked",func {
        foreach(var opt;opts) {
            if(contains(opt,"new_value")) {
                opt.value=opt.new_value;
                opt.changed=1;
                delete(opt,"new_value");
            }
        }
        var r=0;
        if(cb!=nil) r=cb(ret);
        if(r==0) { w.hide(); w.destroy(); }
    });
    
    foreach(var opt;opts) {
        delete(opt,"new_value");
        opt.changed=0;
        ret[opt.name]=opt;
        var wid = _widget[opt.type](opt,szgroups[opt.group],ret);
        if(opt['enabled']!=nil) opt.enable(opt.enabled);
        if(wid!=nil) groups[opt.group].pack_start(wid,0);
    }
    w.show_all();
#    return {bbox:bb,vbox:vbox};
    return nil;
}

var get_value = func(o) { var x=o['new_value']; x==nil?o.value:x; }

var value_hash = func(opts) {
    var h={};
    if(typeof(opts)=="hash") {
        foreach(var k;keys(opts))
            h[k] = opts[k].value;
    } else {
        foreach(var o;opts) {
            h[o.name] = o.value;
        }
    }
    return h;
}

EXPORT=["open","value_hash","get_value"];
