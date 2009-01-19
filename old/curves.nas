import("gtk");
import("cairo");
import("math");
import("options");
import("devices");

import("unix");
import("io");

# TODO
# ----
# Vertical zoom?

# calculate how many value labels that fit nicely? or make 'ngridlabels' property?

# don't draw any line until first event in case its time is not 0
# or force first event time to zero?

# Speed up scrolling by using 2 surfaces, at each redraw copy the old one
# onto the new one with offset.

# Draw peaks only when there is 2 or more values for one pixel

########### Vars and options

var inputs = {
    devs:[],
    height:0,
    graph_height:0,
    redraw:nil,
    label:"inputs",
    scroll:0,
};
var outputs = {
    devs:[],
    height:0,
    graph_height:0,
    redraw:nil,
    label:"outputs",
    scroll:0,
};

var hzoom = 5; #pixels per second
var scroll_t = 0;
var time_font = var time_font_sz = nil;
var grid_min = 0;
var timeline_w = var timeline_h = 0;
var canvas_width = 0;
var max_zoom = 0;
var max_t = 0;
var chan_sep = 4;
var value_font = var value_font_sz = nil;
var follow_now = 0;

var repaint = func nil;
options.add_option("max_zoom",300,func (v) {
    max_zoom = v;
});
options.add_option("input_graph_height",100,func (v) {
    inputs.graph_height = v;
#    redraw_input_curves();
});
options.add_option("output_graph_height",100,func (v) {
    outputs.graph_height = v;
#    redraw_output_curves();
});
options.add_option("timeline_font",["Mono",10],func (v) {
    time_font = v[0]; time_font_sz = v[1];
    lskip = 0;
    repaint();
});
options.add_option("valuegrid_font",["Mono",9],func (v) {
    value_font = v[0]; value_font_sz = v[1];
    repaint();
});
options.add_option("timegrid_min",15,func (v) {
    grid_min = v;
    lskip = 0;
    repaint();
});

########### GUI

var box = gtk.VBox();
var vpane = gtk.VPaned();

var stat_box = devices.get_stat_box(); #gtk.HBox();
var zbox = gtk.HBox("border-width",2,"spacing",2);
zbox.pack_start(gtk.Label("label","zoom"),0);

var z_scale = gtk.HScale("draw-value",0,"width-request",200);
var zoom_adj = z_scale.get("adjustment");
zoom_adj.set("lower",0,"upper",1,"value",0);
zbox.pack_start(z_scale);
zoom_adj.connect("value-changed",func(wid) {
    set_zoom(wid.get("value"));
});

var b = gtk.Button("image",gtk.Image("stock","gtk-zoom-fit"));
#b.connect("clicked",func zoom_adj.set("value",1));
b.connect("clicked",func set_zoom(1));
zbox.pack_start(b,0);

#var b = gtk.CheckButton("label","Follow");
#b.connect("toggled",func(w) {
#    follow_now = w.get("active");
#});
#stat_box.pack_start(b,0,0,5);

var l = gtk.ListStore_new("gchararray");
l.set_row(l.append(),0,"None");
l.set_row(l.append(),0,"Scroll");
l.set_row(l.append(),0,"Zoom");
var b = gtk.ComboBox("model",l,"active",0);
b.add_cell(gtk.CellRendererText(),1,"text",0);
b.connect("changed",func(wid) {
    var r = num(wid.get("active"));
    if(r!=nil) follow_now = r;
});
stat_box.pack_start(gtk.Label("label","Follow:"),0,0,5);
stat_box.pack_start(b,0,0,5);

#var b = gtk.Button("label","Goto Now");
var b = gtk.Button("image",gtk.Image("stock","gtk-jump-to"));
b.connect("clicked",func {
    goto_now();
});
stat_box.pack_start(b,0,0,5);
stat_box.pack_end(zbox,0);
stat_box.pack_end(gtk.VSeparator(),0,0,10);

var out_canvas = gtk.DrawingArea();
var in_canvas = gtk.DrawingArea();

var b = gtk.HBox();
var s = gtk.VScrollbar();
var out_scroll_adj = s.get("adjustment");
out_scroll_adj.set("step-increment",1);
out_scroll_adj.connect("value-changed",func(wid) {
    outputs.scroll = wid.get("value");
    repaint();
});
b.pack_start(out_canvas);
b.pack_start(s,0);
vpane.add(b);

var b = gtk.HBox();
var s = gtk.VScrollbar();
var in_scroll_adj = s.get("adjustment");
in_scroll_adj.set("step-increment",1);
in_scroll_adj.connect("value-changed",func(wid) {
    inputs.scroll = wid.get("value");
    repaint();
});
b.pack_start(in_canvas);
b.pack_start(s,0);
vpane.add(b);

var timeline_canvas = gtk.DrawingArea();
options.add_option("timeline_height",30,func (v) {
    timeline_h = v;
    timeline_canvas.set("height-request",v);
    repaint();
});

var time_scrollbar = gtk.HScrollbar();
var time_scroll_adj = time_scrollbar.get("adjustment");
time_scroll_adj.set("step-increment",1);

box.pack_start(timeline_canvas,0);
box.pack_start(vpane);
box.pack_end(stat_box,0);
box.pack_end(time_scrollbar,0);

######################

var set_zoom = func(z) {
    hzoom = 1/(math.pow(max_zoom*max_t/(canvas_width-10),z)/max_zoom);
    lskip = 0; # recalculate timegrid interval
    redraw_all(z==1?1:0);
}

var update_max_t = func(t) {
    if(t>max_t) {
        max_t=t;
        time_scroll_adj.set("upper",t);
    }
}

var setup = func() {
    var setup = devices.get_setup();
    inputs.devs = setup.inputs;
    outputs.devs = setup.outputs;
    max_t = 0;
    update_max_t(10);
    foreach(var x;inputs.devs) {
        if(size(x.data)) update_max_t((1/x.freq)*size(x.data));
        x._surface = nil;
        x._height = inputs.graph_height;
    }
    foreach(var x;outputs.devs) {
        if(size(x.data)) update_max_t(x.data[-1][0]);
        x._surface = nil;
        x._height = outputs.graph_height;
    }
    var outs_height = (chan_sep+outputs.graph_height)*size(outputs.devs);
    in_scroll_adj.set("upper",(chan_sep+inputs.graph_height)*size(inputs.devs),"value",0);
    out_scroll_adj.set("upper",outs_height,"value",0);
    vpane.set("position",outs_height);
    zoom_adj.set("value",1);
    repaint();
}

var time2x = func(t) t*hzoom;
var x2time = func(x) x/hzoom;

var setup_cairo = func(surface) {
    var cr = cairo.create(surface);
    cairo.set_operator(cr,cairo.OPERATOR_CLEAR);
    cairo.paint(cr);
    cairo.set_operator(cr,cairo.OPERATOR_OVER);
    cairo.set_line_width(cr,1);
    return cr;
}
var mk_surf = func(cr,w,h) {
    return cairo.surface_create_similar(cairo.get_target(cr),
            cairo.CONTENT_COLOR_ALPHA, w, h);
}

var timeline_configure = func(wid,ev) {
    timeline_w = ev.width;
    timeline_h = ev.height;
#    vscroll_adj.set("page-size",canvas_h);
#    if(first_conf) {
#        zoom_adj.set("value",1);
#        first_conf=0;
#    }
}

var timeline_expose = func(w,ev) {
    if(ev.count!=0) return 0;
    var cr = w.cairo_create();
    cairo.translate(cr,0.5,0.5);
    cairo.set_line_width(cr,1);
    cairo.set_source_rgb(cr,1,1,1);
    cairo.paint(cr);
    redraw_timegrid(cr,1,timeline_w,timeline_h);
    return 0;
}

var draw_chan_header = func(cr,i) {
    cairo.set_source_rgb(cr,1,1,1);
    cairo.paint(cr);
    cairo.set_source_rgb(cr,0,0,0);
    cairo.move_to(cr,40,10);
    cairo.select_font_face(cr,"Sans");
    cairo.set_font_size(cr,10);
    cairo.show_text(cr,i.name);
    
    if(i['ngrids']!=nil) {
        var fmt = i.min<0 or i.max<0 ? "%+.2f" : "%.2f";
        cairo.select_font_face(cr,value_font);
        cairo.set_font_size(cr,value_font_sz);
        cairo.set_source_rgb(cr,0.8,0.3,0.3);
        var fx = cairo.text_extents(cr,sprintf(fmt,i.max));
        var gs = (i._height-fx.height-4)/(i.ngrids-1);
        var z = (i.min-i.max)/(i.ngrids-1);
        for(var y=0;y<i.ngrids;y+=1) {
            cairo.move_to(cr,2,int(fx.height+2+y*gs));
            cairo.show_text(cr,sprintf(fmt,z*y+i.max));
        }
        cairo.set_line_width(cr,1);
        cairo.set_source_rgb(cr,1,0.6,0.6);
        var gs = (i._height-1)/(i.ngrids-1);
        for(var y=0;y<i.ngrids;y+=1) {
            cairo.move_to(cr,y==0 or y==i.ngrids-1 ? 0 : fx.x_advance+4,int(y*gs));
            cairo.rel_line_to(cr,canvas_width,0);
        }
        cairo.stroke(cr);
    }
}

var usrval2y = func(ch,v) ch._height-(((v-ch.min)/(ch.max-ch.min))*ch._height);
#NOTE: Data is stored in raw device format, not scaled.
var val2y = func(ch,v) ch._height-((v/ch.dev_max)*ch._height);

var chan_msg = func(cr,i,s) {
    cairo.select_font_face(cr,"Sans");
    cairo.set_font_size(cr,14);
    cairo.set_source_rgb(cr,1,0,0);
    cairo.move_to(cr,canvas_width/2,i._height/2);
    cairo.show_text(cr,s);
}

inputs.redraw = func(i) {
    var cr = cairo.create(i._surface);
    cairo.translate(cr,0.5,0.5);
    draw_chan_header(cr,i);
    if(!size(i.data)) {
        chan_msg(cr,i,"no data");
        return;
    }
    cairo.move_to(cr,0,usrval2y(i,i.center)); #is this right?
    var rate = 1 / i.freq;
    var start = int(scroll_t)*i.freq;
    if(start>=size(i.data)) return;    
    var t = 0;
    var y = var x = 0;
#    var mid = [];
    
    for(var q=start;q<size(i.data);q+=1) {
    #FIXME: for all values with same x pixel, collect midvalue to y...
        x = int(time2x(t));
        y = val2y(i,i.data[q]);
        
        cairo.line_to(cr,x,y);
        if(x>canvas_width) break;
        t += rate;
    }
    cairo.set_line_width(cr,1);
    cairo.set_source_rgb(cr,0,0,0);
    cairo.stroke_preserve(cr);

#    cairo.line_to(cr,canvas_width,y);
    cairo.line_to(cr,x,usrval2y(i,i.center));
    cairo.set_source_rgba(cr,0,1,0,0.2);
    cairo.fill(cr);
}

outputs.redraw = func(i) {
    var cr = cairo.create(i._surface);
    cairo.translate(cr,0.5,0.5);
    draw_chan_header(cr,i);
    if(!size(i.data)) {
        chan_msg(cr,i,"no data");    
        return;
    }
    cairo.move_to(cr,0,val2y(i,i.center)); #is this right?
    var visible = 0;
    var start = 0;
    var oy = val2y(i,i.data[0][1]);
    forindex(var q;i.data) {
        if(time2x(i.data[q][0]-scroll_t)>=0) {
            visible = 1;
            break;
        } else {
            oy = val2y(i,i.data[q][1]);
            start = q;
        }
    }
    if(!visible) return;
    var x = 0;
    for(var q = start;q<size(i.data);q+=1) {
        var ev = i.data[q];
        x = int(time2x(ev[0]-scroll_t));
        var y = int(val2y(i,ev[1]));
        if(!i.line) {
            cairo.line_to(cr,x,oy);
        }
        cairo.line_to(cr,x,y);
        oy = y;
        if(x>canvas_width) break;
    }
    cairo.set_line_width(cr,1);
    cairo.set_source_rgb(cr,0,0,0);
    cairo.stroke_preserve(cr);

    cairo.line_to(cr,canvas_width,oy);
    cairo.line_to(cr,canvas_width,val2y(i,i.center));
    cairo.set_source_rgba(cr,0,1,0,0.2);
    cairo.fill(cr);
}

var in_configure = func(wid,ev) {
    canvas_width = ev.width;
    inputs.height = ev.height;
    in_scroll_adj.set("page-size",ev.height);
    foreach(var i; inputs.devs) i._surface=nil;
}

var out_configure = func(wid,ev) {
    outputs.height = ev.height;
    out_scroll_adj.set("page-size",ev.height);
    foreach(var i; outputs.devs) i._surface=nil;
}

var io_expose = func(wid,ev,set) {
    if(ev.count!=0) return 0;
#  var t = unix.time();
    var cr = wid.cairo_create();
    cairo.set_line_width(cr,1);
    cairo.translate(cr,0,-int(set.scroll));
#    cairo.set_source_rgb(cr,1,1,1);
#    cairo.paint(cr);
    var pos = chan_sep;
    foreach(var i;set.devs) {
        if(i._surface==nil) {
            i._surface=mk_surf(cr,canvas_width,i._height);
            i._redraw=1;
            i._pos=pos;
        }
        if(i._redraw) {
            i._redraw=0;
            set.redraw(i);
        }
        cairo.set_source_surface(cr,i._surface,0,pos);
        cairo.paint(cr);
        pos += i._height + chan_sep;
    }
    cairo.select_font_face(cr,"Sans");
    cairo.set_font_size(cr,10);
    cairo.translate(cr,0,int(set.scroll));
    var x = cairo.text_extents(cr,set.label);
    cairo.set_source_rgb(cr,0,0,1);
    cairo.move_to(cr,canvas_width-x.x_advance-5,x.height+chan_sep);
    cairo.show_text(cr,set.label);
    cairo.translate(cr,0.5,0.5);
    redraw_timegrid(cr,0,canvas_width,set.height);
#  io.write(io.stdout,sprintf("%g\n",(unix.time()-t)*1000));
}

var gskip = var lskip = var ldx = var gdx = var ts_height = 0;
var redraw_timegrid = func(cr,do_labels,width,height) {
    var xpad = 5;
    var ypad = 15;

    cairo.select_font_face(cr,time_font);
    cairo.set_font_size(cr,time_font_sz);

    if(lskip==0) {
        ts_height = cairo.font_extents(cr).height;
        var ext = cairo.text_extents(cr,"999'59");
        var tg = time2x(1); # pixels per one second
        var divs = [1,2,10,20,30,60];

        foreach(lskip;divs) {
            if(tg*lskip>ext.x_advance) break;
        }
        foreach(gskip;divs) {
            if(tg*gskip>grid_min) break;
        }
        ldx = tg*lskip;
        gdx = tg*gskip;
    }

    if(scroll_t==0) {
        var lx = var gx = var s = 0;
    } else {
        var lx = time2x(-math.mod(scroll_t,lskip));
        var gx = time2x(-math.mod(scroll_t,gskip));
        var s = int(scroll_t);
        s -= math.mod(s,lskip);
    }
    if(gx<0) gx+=gdx;
    if(lx<0) { lx+=ldx; s+=lskip; }

    if(do_labels) {
        for(var n=lx;int(n)<=width;n+=ldx) {
            cairo.move_to(cr,int(n),0);
            cairo.rel_line_to(cr,0,ypad);
            cairo.set_source_rgb(cr,0.6,0.6,0.6);
            cairo.stroke(cr);

            var min = int(s/60);
            var sec = math.mod(s,60);
            if(sec==0) {
                cairo.set_font_size(cr,time_font_sz*1.5);
                var txt = min~"'";
            } else {
                cairo.set_font_size(cr,time_font_sz);
                var txt = min~"'"~sec;
            }
            cairo.move_to(cr,int(n+1),ypad);
            cairo.set_source_rgb(cr,0,0,0);
            cairo.show_text(cr,txt);
            s += lskip;
        }
    } else {
        ypad = 0;
    }
    cairo.set_dash(cr,[2,4]);
    cairo.set_source_rgb(cr,0.6,0.6,0.6);
    for(var n=gx;int(n)<=width;n+=gdx) {
        cairo.move_to(cr,int(n),ypad);
        cairo.rel_line_to(cr,0,height);
        cairo.stroke(cr);
    }
    cairo.set_dash(cr,0);
}

var repaint = func {
    timeline_canvas.queue_draw();
    out_canvas.queue_draw();
    in_canvas.queue_draw();
}

var redraw_all = func(reset_scroll=0) {
#    var t=unix.time();
    if(reset_scroll) time_scroll_adj.set("value",0);
    foreach(var i;inputs.devs) i._redraw = 1;
    foreach(var i;outputs.devs) i._redraw = 1;
    repaint();
#    print((unix.time()-t)*1000,"\n");
#    This doesn't actually measure the drawing time since I guess
#    the drawing operations are queued and executed in the glib mainloop
#    or even in the X server...
}

var edit_data = func(ch) {
    if(ch['_edit_window']!=nil) {
        ch._edit_window.show_all(); #FIXME: wrap GtkWindow.present()
        return;
    }
    var store = gtk.ListStore_new("gchararray","gchararray");
    var edit_time = func(wid,row,val) {
        update_max_t(ch.data[row][0]=val);
        update(row);
    }
    var edit_value = func(wid,row,val) {
    #NOTE: should this be in raw device values or scaled to user min/max?
        val=int(val);
        if(val>ch.dev_max) val=ch.dev_max;
        elsif(val<0) val=0;
        ch.data[row][1]=val;
        update(row);
    }
    var update = func(row=nil) {
        ch.data = sort(ch.data,func(a,b) a[0]>b[0]);
        store.clear();
        foreach(var x;ch.data)
            store.set_row(store.append(),0,x[0],1,x[1]);
        if(row!=nil) view.get_selection().select(row);
        ch._redraw = 1;
        repaint();
    }
    var _close = func {
#        ch._edit_window=nil;
        w.hide();
#        w.destroy();
    }
    var _add = func {
        var row = view.get_selection().get_selected();
        if(row!=nil) {
            var t = store.get_row(row,0)+1;
            append(ch.data,[t,0]);
            update(row+1);
        } else {
            append(ch.data,[0,0]);
            update(0);
        }
    }
    var _remove = func {
        var row = view.get_selection().get_selected();
        if(row==nil) return;
        ch.data = subvec(ch.data,0,row) ~ subvec(ch.data,row+1);
        update(row);
    }
    ch._edit_window = var w = gtk.Window("title","Edit output: "~ch.name);
    w.set("default-height",400,"default-width",200);
    w.connect("delete-event",_close);
    var view = gtk.TreeView("model",store);
    var col = gtk.TreeViewColumn("title","Time");
    col.add_cell(var cell = gtk.CellRendererText("editable",1),0,"text",0);
    view.append_column(col);
    cell.connect("edited",edit_time);
    var col = gtk.TreeViewColumn("title","Value");
    col.add_cell(var cell = gtk.CellRendererText("editable",1),0,"text",1);
    view.append_column(col);
    cell.connect("edited",edit_value);
    var sw = gtk.ScrolledWindow();
    sw.add(view);
    var box = gtk.VBox();
    var bb = gtk.HButtonBox("border-width",4);
    box.pack_start(gtk.Label("label","Time is in seconds, Value as 0 to "~ch.dev_max),0,0,5);
    box.pack_start(sw);
    box.pack_start(bb,0);
    w.add(box);
    
    foreach(var but;[
        ["gtk-add", _add],
        ["gtk-remove",_remove],
        ["gtk-close",_close],
    ]) {
        bb.add(var b = gtk.Button("label",but[0],"use-stock",1));
        b.connect("clicked",but[1]);
    }
   
    update(); 
   
    w.show_all();
}

var outputs_click = func(wid,ev) {
    if(ev.type!="2button-press") return;
    foreach(var ch;outputs.devs) {
        if(ev.y>ch._pos and ev.y<ch._pos+ch._height) {
            edit_data(ch);
            return;
        }
    }
}

timeline_canvas.connect("expose-event",timeline_expose);
timeline_canvas.connect("configure-event",timeline_configure);

in_canvas.connect("expose-event",io_expose,inputs);
in_canvas.connect("configure-event",in_configure);

out_canvas.set("events",{"button-press-mask":1});
out_canvas.connect("expose-event",io_expose,outputs);
out_canvas.connect("configure-event",out_configure);
out_canvas.connect("button-press-event",outputs_click);

time_scroll_adj.connect("value-changed",func(wid) {
    scroll_t = int(wid.get("value"));
    redraw_all();
});

devices.set_notify_cb(func(i) {
    update_max_t((1/i.freq)*size(i.data));
    i._redraw = 1;
});

var goto_now = func {
    var t = devices.get_now();
    t -= x2time(canvas_width*0.9);
    if(t<0) t=0;
    time_scroll_adj.set("value",t);
}

gtk.timeout_add(500,func {
    if(follow_now==1) goto_now();
    elsif(follow_now==2) set_zoom(1);
    in_canvas.queue_draw();
    return 1;
});

devices.set_clr_cb(func {
    redraw_all(1);
});

var init = func box;

EXPORT = ["init","setup","redraw_all"];
