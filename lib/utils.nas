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
import("globals","*");

var confirm_dialog = func(title,msg,yes_cb,no_cb=nil) {
    var d = gtk.Window("title",title,"transient-for", globals.top_window, "window-position","center-on-parent","border-width",10);
    var v = gtk.VBox("spacing",10);
    v.add(gtk.Label("label",msg));
    var h = gtk.HBox("spacing",10);
    var b2 = gtk.Button("label","gtk-no","use-stock",1);
    var b1 = gtk.Button("label","gtk-yes","use-stock",1);
    h.add(b2);
    h.add(b1);
    v.add(h);
    d.add(v);
    b1.connect("clicked",func {
        d.hide();
        d.destroy();
        yes_cb();
    });
    b2.connect("clicked",func {
        d.hide();
        d.destroy();
        if(no_cb!=nil) no_cb();
    });
    d.show_all();
}

var msg_dialog = func(title,msg,icon="info",cb=nil) {
    var d = gtk.Window("title",title,"transient-for", globals.top_window, "window-position","center-on-parent","border-width",10);
    var v = gtk.VBox("spacing",10);
    var hb = gtk.HBox("spacing",10);
    hb.pack_start(gtk.Image("stock","gtk-dialog-"~icon),0);
    hb.add(gtk.Label("label",msg));
    v.add(hb);
    var h = gtk.HButtonBox("spacing");
    var b2 = gtk.Button("label","gtk-ok","use-stock",1);
    h.add(b2);
    v.add(h);
    d.add(v);
    b2.connect("clicked",func {
        d.hide();
        d.destroy();
        if(cb!=nil) cb();
    });
    d.show_all();
}

var copy = func(src) {
    var t = typeof(src);
    if(t=="vector") {
        var x=setsize([],size(src));
        forindex(var i;src)
            x[i]=copy(src[i]);
        return x;
    } elsif(t=="hash") {
        var x={};
        foreach(var k;keys(src)) {
            x[k]=copy(src[k]);
        }
        return x;
    } else
        return src;
}

#var sort = func(v) {
#    var _sort = func(lo,hi) {
#        var i = lo;
#        var j = hi;
#        var x = v[(lo+hi)/2];
#        while(1) {
#            while(cmp(v[i],x)<0) i+=1;
#            while(cmp(v[j],x)>0) j-=1;
#            if(i<=j) {
#                var t = v[i];
#                v[i]=v[j];
#                v[j]=t;
#                i+=1;
#                j-=1;
#            } else {
#                break;
#            }
#            if(lo<j) _sort(lo,j);
#            if(i<hi) _sort(i,hi);
#        }
#    }
#    _sort(0,size(v)-1);
#    return v;
#}

var stacktrace = func(err,stop_at_file=nil) {
    var x = "";
    x ~= sprintf("Runtime error: %s\n", err[0]);
    for(var i=1; i<size(err); i+=2) {
	x ~= sprintf("  %s %s line %d\n", i==1 ? "at" : "called from",
                     err[i], err[i+1]);
        if(err[i]==stop_at_file) break;
    }
    return x;
}
