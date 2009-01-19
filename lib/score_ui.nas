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
import("gtk");
import("cairo");
import("options");
import("math");
import("propbox");
import("debug");
import("palette");
import("playbus");
import("unix");
import("optbox");
import("progress");
import("outbus");
import("interval");
import("inspector");
import("globals","*");

var scroll_t = 0;
var scroll_y = 0;
var time_font = var time_font_sz = nil;
var con_font = var con_font_sz = nil;
var grid_min = 0;
var timeline_w = var timeline_h = 0;
var canvas_width = 0;
var canvas_height = 0;
var surf_width = 0;
var max_zoom = 0;
var follow_now = 0;
var pointer_x = 0;
var pointer_y = 0;
var score = nil;
var highlighted_obj = nil;
var y_grid = 0;
var enable_outlines = 0;
var enable_labels = 0;
var edit_obj = nil;
var enable_unused_reg = 0;

var did_scroll = 1;

var tool_mode = nil;
#var tool_keys = {'o':'object', 'a':'alignment', 'c':'copy', 'i':'insert'};

var repaint = func nil;
options.add_option("max_zoom",800,func (v) {
    max_zoom = v;
});
options.add_option("timeline_font",["Mono",10],func (v) {
    time_font = v[0]; time_font_sz = v[1];
    lskip = 0;
    repaint();
});
options.add_option("connection_font",["Sans",8],func (v) {
    con_font = v[0]; con_font_sz = v[1];
    lskip = 0;
    repaint();
});
options.add_option("timegrid_min",15,func (v) {
    grid_min = v;
    lskip = 0;
    repaint();
});
options.add_option("vertical_grid",15,func (v) {
    y_grid = v;
#    lskip = 0;
#    repaint();
});

options.add_option("show_unused_regions",0,func (v) {
    enable_unused_reg = v;
    repaint();
});

options.add_option("palette",'default',func(f) {
    var path = algoscore.locate_file(f~'.pal');
    if(path!=nil) palette.load_style(path);
#    palette.load_style(lib_dir~'/'~v~'.pal');
    repaint();
});

options.add_option("gfx_cache_factor",2);

########### GUI

var btn3 = func(ev) ev.button==3 or ev.state['meta-mask']==1;

var do_connect_menu = func(title,choices,cb,disctag=0,button=0,time=nil) {
    var m = gtk.Menu();
    var value = nil;
    m.connect("selection-done",func {
        cb(value);
        m.destroy();
    });
    var i = gtk.MenuItem("sensitive",0);
    i.add(gtk.Label("label",title));
    i.show_all();
    m.add(i);
    var i = gtk.SeparatorMenuItem();
    i.show_all();
    m.add(i);
    var mk_cb = func(x) { func(item) value = x; }
    foreach(var c; choices) {
        var i = gtk.MenuItem();
        if(c[0]==`.`) {
            var l=c=substr(c,1);
            i.set("sensitive",0);
        } elsif(c[0]==`,`) {
            c=substr(c,1);
            var l="("~c~")";
        } else {
            var l=c;
        }
        i.add(gtk.Label("label",l));
        i.show_all();
        m.add(i);
#        i.connect("activate",func(item,x) value = x, c);
        i.connect("activate",mk_cb(c));
    }

#    var i = gtk.SeparatorMenuItem();
#    i.show_all();
#    m.add(i);
#    i = gtk.MenuItem();
#    i.add(gtk.Label("use-markup",1,"label","<i>(dependency)</i>"));
#    i.show_all();
#    m.add(i);
#    i.connect("activate",func value = "*dep*");

    if(disctag) {
        var i = gtk.SeparatorMenuItem();
        i.show_all();
        m.add(i);
        i = gtk.MenuItem();
        i.add(gtk.Label("use-markup",1,"label","<i>disconnect</i>"));
        i.show_all();
        m.add(i);
        i.connect("activate",func value = "");
    }
    if(time!=nil) m.popup(button, time);
    else m.popup(button);
    return m;
}

var tips = gtk.Tooltips();

var box = gtk.VBox();
var vpane = gtk.VPaned();

var stat_box = gtk.HBox("border-width",3);
var zbox = gtk.HBox("border-width",0,"spacing",2);
zbox.pack_start(gtk.Label("label","zoom"),0);

var z_scale = gtk.HScale("draw-value",0,"width-request",200);
var zoom_adj = z_scale.get("adjustment");
zoom_adj.set("lower",0,"upper",2,"value",0);
zbox.pack_start(z_scale);
zoom_adj.connect("value-changed",func(wid) {
    set_zoom(wid.get("value"));
});

var zoom_fit_all = func {
    zoom_adj.set("value",1);
    zoom_adj.value_changed();
    time_scroll_adj.set("upper",score.endmark.time);
    scroll_home_x();
#    time_scroll_adj.set("value",score.x2time(-10));
#    time_scroll_adj.set("value",0);
}

var b = gtk.Button("image",gtk.Image("stock","gtk-zoom-fit"));
b.connect("clicked", zoom_fit_all);
#b.connect("clicked",func set_zoom(1));
zbox.pack_start(b,0);

#var l = gtk.ListStore_new("gchararray");
#l.set_row(l.append(),0,"None");
#l.set_row(l.append(),0,"Scroll");
#l.set_row(l.append(),0,"Zoom");
#var b = gtk.ComboBox("model",l,"active",0);
#b.add_cell(gtk.CellRendererText(),1,"text",0);
#b.connect("changed",func(wid) {
#    var r = num(wid.get("active"));
#    if(r!=nil) follow_now = r;
#});
#stat_box.pack_start(gtk.Label("label","Follow:"),0,0,5);
#stat_box.pack_start(b,0,0,5);

var locate_pos = 0;
var playpos = 0;
var playstate = 0;


#stat_box.pack_start(gtk.VSeparator(),0,0,10);
#stat_box.pack_start(gtk.EventBox(),0,0,20);

var b = gtk.ToggleButton("image",gtk.Image("stock","gtk-select-color"),"active",enable_outlines);
#var b = gtk.CheckButton("label","Outlines","active",enable_outlines);
b.connect("toggled",func(w) {
    enable_outlines = w.get("active");
    canvas.queue_draw();
});
stat_box.pack_start(b,0,0,2);
var outlines_toggle = b;
tips.set_tip(b,"draw object outlines");

var b = gtk.ToggleButton("image",gtk.Image("stock","gtk-select-font"),"active",enable_labels);
#var b = gtk.CheckButton("label","Labels","active",enable_labels);
b.connect("toggled",func(w) {
    enable_labels = w.get("active");
    canvas.queue_draw();
});
stat_box.pack_start(b,0,0,2);
var labels_toggle = b;
tips.set_tip(b,"draw object labels");

stat_box.pack_start(gtk.VSeparator(),0,0,10);
#stat_box.pack_start(gtk.EventBox(),0,0,20);

#var b = gtk.CheckButton("label","Delay update","active",0);
var b = gtk.ToggleButton("image",gtk.Image("stock","gtk-refresh"),"active",1);
b.connect("toggled",func(w) {
    score.delay_update = !w.get("active");
    if(!score.delay_update)
        score.update_all();
});
stat_box.pack_start(b,0,0,2);
var delay_update_toggle = b;
tips.set_tip(b,"update objects automatically,\nif unset: queue updates");

var b = gtk.Button("image",gtk.Image("stock","gtk-execute"));
b.connect("clicked",func(w) {
    score.update_all(0,nil,1);
});
var update_button = b;
stat_box.pack_start(b,0,0,2);
tips.set_tip(b,"perform all pending updates now");

var b = gtk.Button("image",gtk.Image("stock","gtk-stop"));
b.connect("clicked",func(w) {
    outbus.cancel_all();
});
stat_box.pack_start(b,0,0,2);
tips.set_tip(b,"stop all background updates");


stat_box.pack_start(gtk.VSeparator(),0,0,10);

var b = gtk.Button("image",gtk.Image("stock","gtk-media-previous"));
b.connect("clicked",func locate(0));
stat_box.pack_start(b,0,0,2);

var play_mon_id = interval.add_proc(func {
    var pos = playbus.get_play_pos();
    if(pos<0) {
        if(playstate) playbutton.clicked();
        return 0;
    }
    set_playpos(pos);
    return playstate;
},0);

var b = gtk.ToggleButton("image",gtk.Image("stock","gtk-media-play"));
b.connect("toggled",func(w) {
    playstate = w.get("active");
    if(playstate) {
        playbus.set_end(score.endmark.time);
        interval.enable_proc(play_mon_id);
    }
    playbus.set_play_state(playstate);
});
stat_box.pack_start(b,0,0,2);
var playbutton = b;
tips.set_tip(b,"play/stop");

var time_lbl = gtk.Label("name","timelabel");
var set_playpos = func(sec) {
    playpos = sec;
    var min = int(sec/60);
    var str = sprintf("%02d:%05.2f",min,math.mod(sec,60));
    time_lbl.set("label",str);
    canvas.queue_draw();
}
stat_box.pack_start(time_lbl,0,0,10);

var b = gtk.Button("image",gtk.Image("stock","gtk-jump-to"));
b.connect("clicked",func {
    goto_now();
});
stat_box.pack_start(b,0,0,2);
tips.set_tip(b,"scroll to play position");

var b = gtk.ToggleButton("image",gtk.Image("stock","gtk-goto-last"));
#var b = gtk.CheckButton("label","Follow");
b.connect("toggled",func(w) {
    follow_now = w.get("active");
});
stat_box.pack_start(b,0,0,2);
tips.set_tip(b,"follow play cursor");

#stat_box.pack_start(gtk.EventBox(),1,0,10);


stat_box.pack_end(zbox,0);
stat_box.pack_end(gtk.VSeparator(),0,0,10);

#var tool_lbl = gtk.Label("use-markup",1,"name","tool_label");
#stat_box.pack_end(tool_lbl,1);
#var set_tool = func(t) {
#    tool_mode = t;
#    tool_lbl.set("label","<b>"~t~"</b>");
#    canvas.queue_draw();
#}

var tools = [
    {
        name:"object",
        image:"arrow.png",
        key:"o",
        tooltip:"Basic object manipulations"
    },
    {
        name:"copy",
        image:"copy.png",
        key:"c",
        tooltip:"Object duplication"
    },
    {
        name:"alignment",
        image:"align.png",
        key:"a",
        tooltip:"Object alignment and linking"
    },
    {
        name:"insert",
        image:"insert.png",
        key:"i",
        tooltip:"Insert or remove time in score"
    },
];
var set_tool = func(k) {
    foreach(t;tools) {
        if(t.name==k) t.btn.set("active",1);
    }
}
var check_tool_key = func(key) {
    foreach(t;tools) {
        if(t.key==key) {
            set_tool(t.name);
            return 1;
        }                
    }
    return 0;
}
var tool_box = gtk.HBox("spacing",0);
var setup_tool_button = func(t) {
    var b = gtk.ToggleButton("image",gtk.Image("file",lib_dir~"/icons/"~t.image));
    tips.set_tip(b,t.tooltip~"\nkey: "~t.key);
    t.btn = b;
    tool_box.pack_start(b,0);
    b.connect("toggled",func(wid) {
        if(wid.get("active")) {
            tool_mode = t.name;
            foreach(t2;tools) {
                if(t2.name!=tool_mode)
                    t2.btn.set("active",0);
            }
#            print("tool: -",tool_mode,"-\n");
            canvas.queue_draw();
        } elsif(t.name==tool_mode) set_tool("object");
    });
}
foreach(t;tools) setup_tool_button(t);
stat_box.pack_end(tool_box,0);

stat_box.pack_end(gtk.VSeparator(),0,0,10);
var canvas = gtk.DrawingArea();
#canvas.set_double_buffered(0);

var b = gtk.HBox();
var s = gtk.VScrollbar();
var scroll_adj = s.get("adjustment");
scroll_adj.set("step-increment",1,"upper",1000,"lower",-1000);
scroll_adj.set("page-size",1);
scroll_adj.connect("value-changed",func(wid) {
    scroll_y = wid.get("value");
    repaint();
});
b.pack_start(canvas);
b.pack_start(s,0);
vpane.add(b);

var timeline_canvas = gtk.DrawingArea();
options.add_option("timeline_height",20,func (v) {
    timeline_h = v;
    timeline_canvas.set("height-request",v);
    repaint();
});

var time_scrollbar = gtk.HScrollbar();
var time_scroll_adj = time_scrollbar.get("adjustment");
time_scroll_adj.set("step-increment",1,"lower",-1);

box.pack_start(timeline_canvas,0);
box.pack_start(vpane);
box.pack_end(stat_box,0);
box.pack_end(time_scrollbar,0);

######################

var set_zoom = func(z) {
#    var t = score.max_t;
    var t = score.endmark.time;
    if(t<1) t=1; # at least one sec
    z = int(10*z)/10;
    var z2 = 1/(math.pow(max_zoom*t/(canvas_width-20),z)/max_zoom);
    if(z2==score.zoom) return;
    score.zoom = z2;
    lskip = 0; # recalculate timegrid interval

    # recreate all object surfaces
    foreach(var k;keys(score.objects))
        score.objects[k].remake_surface();

    repaint();
}

var setup_cairo = func(surface) {
    var cr = cairo.create(surface);
    cairo.set_operator(cr,cairo.OPERATOR_CLEAR);
    cairo.paint(cr);
    cairo.set_operator(cr,cairo.OPERATOR_OVER);
    cairo.set_line_width(cr,1);
    palette.use_color(cr,"fg");
    return cr;
}
var mk_surf = func(cr,w,h) {
    return cairo.surface_create_similar(cairo.get_target(cr),
            cairo.CONTENT_COLOR_ALPHA, w, h);
}

var timeline_configure = func(wid,ev) {
    timeline_w = ev.width;
    timeline_h = ev.height;
}

var timeline_expose = func(w,ev) {
    if(ev.count!=0) return 1;
    var cr = w.cairo_create();
    cairo.translate(cr,0.5,0.5);
    cairo.set_line_width(cr,1);
    palette.use_color(cr,"bg");
    cairo.paint(cr);
    redraw_timegrid(cr,1,timeline_w,timeline_h);
    cairo.destroy(cr);
    return 1;
}

var first_conf = 1;
var canvas_configure = func(wid,ev) {
    canvas_height = ev.height;
    canvas_width = ev.width;
   
#    time_scroll_adj.set("page-size",score.x2time(ev.width));

    if(first_conf) {
        var f = options.get("gfx_cache_factor");
        if(f<=1) {
            print("gfx_cache_factor must be greater than 1.0, setting to 2.0\n");
            f=2;
        }
        surf_width = wid.get_screen_width()*f;
#        print("gfx cache width: ",surf_width," pixels\n");

        zoom_adj.set("value",1);
        first_conf = 0;
#        repaint();
    }

    foreach(var k;keys(score.objects)) {
        var o = score.objects[k];
        if(o.sticky) o.remake_surface();
    }
}

var get_y_range = func {
    var y1 = nil;
    var y2 = nil;
    foreach(var k;keys(score.objects)) {
        var obj = score.objects[k];
        if(y1==nil or obj.ypos<y1) y1=obj.ypos;
        if(y2==nil or obj.ypos+obj.height>y2) y2=obj.ypos+obj.height;
    }
    if(y1==nil) {y1=y2=0};
    return [int(y1),int(y2)];
}
var scroll_home_x = func {
    time_scroll_adj.set("value",score.x2time(-10));
}
var scroll_home_y = func {
    if(size(score.objects)<1) return;
    var y = get_y_range()[0];
    scroll_adj.set("value",y-10);
}
var scroll_home = func {
    scroll_home_x();
    scroll_home_y();
}

var draw_varrow = func(cr, x, y0, y1) {
    var yy = y1>y0?y1-8:y1+8;
#    var yy2 = y1>y0?y1-4:y1+4;
    cairo.move_to(cr,x,y0);
    cairo.line_to(cr,x,yy);
    cairo.stroke(cr);
    cairo.move_to(cr,x-3,yy);
    cairo.line_to(cr,x,y1);
    cairo.line_to(cr,x+3,yy);
    cairo.fill(cr);
}

var update_con_pos = func(obj,con) {
    var src = con.srcobj;
#                var x = int(score.time2x(con.draw_pos+obj.start));
    var objx = obj.sticky?0:obj.xpos;
    var x = int(score.time2x(con.draw_pos)+objx);

    var mx = obj.sticky?src.xpos:math.max(src.xpos,objx);
    if(x<mx) {
        x=mx;
    } else {
        var src_end = src.xpos+src.width;
        mx = obj.sticky?src_end:math.min(src_end,objx+obj.width);
        if(x>mx) x=mx;
    }

    if(src.ypos<obj.ypos) {
#        var y0 = src.ypos+src.height;
#        var y1 = obj.ypos;
        var y0 = src.get_con_bottom_ypos(x);
        var y1 = obj.get_con_top_ypos(x);
    } else {
#        var y0 = src.ypos;
#        var y1 = obj.ypos+obj.height;
        var y0 = src.get_con_top_ypos(x);
        var y1 = obj.get_con_bottom_ypos(x);
    }

    con.x_pos = x;
    con.y0_pos = y0;
    con.y1_pos = y1;

#   print("con.x_pos=",con.x_pos," src.xpos=",src.xpos," obj.width=",obj.width,"\n");

}

var for_each_con = func(obj, cb) {
    if(obj.con_cache==nil) {
#        print(obj.get_label(),": updating con_cache. obj.start=",obj.start,"\n");
        var con_list = [];
        foreach(var in;keys(obj.inlets)) {
            var inlet = obj.inlets[in];
            foreach(var k;keys(inlet.connections)) {
                var con = inlet.connections[k];
                update_con_pos(obj,con);
                con.inlet_name = in;
                append(con_list,con);
            }
        }
        obj.con_cache = sort(con_list,func(a,b) a.x_pos < b.x_pos);
    }

#FIXME: since now all stuff is stored in con, we don't need this cb stuff..
#simply do foreach(var con;ensure_con_cache(obj)).
    foreach(var con;obj.con_cache)
        cb(con,con.inlet_name,con.x_pos,con.y0_pos,con.y1_pos);
}

var draw_connections = func(cr, obj) {
    cairo.save(cr);
    cairo.translate(cr,0.5,0.5);
#    cairo.set_source_rgb(cr,0,0,0);
    palette.use_color(cr,"connection");
    cairo.set_line_width(cr,1);
    cairo.select_font_face(cr,con_font);
    cairo.set_font_size(cr,con_font_sz);
    var last_inlet = nil;
    for_each_con(obj, func(con,inlet,x,y0,y1) {
        # FIXME: take care of single-value objects (length==0) ?
        # ignore it's length and only check that its start is within obj.start->obj.length..
        var src = con.srcobj;
        var out_left = src.start+src.length < obj.start;
        var out_right = src.start > obj.start+obj.length;
        if(!obj.sticky and (out_left or out_right)) {
            var x0 = out_left ? src.xpos+src.width : src.xpos;
            var x1 = out_right ? obj.xpos+obj.width : obj.xpos;
            cairo.save(cr);
            palette.use_color(cr,"con_error");
            cairo.move_to(cr,x0,y0);
            cairo.line_to(cr,x1,y1);
            cairo.stroke(cr);
            cairo.restore(cr);
        } else {
            draw_varrow(cr,x,y0,y1);
            if(y0<y1) { y0+=7; y1-=3; var y2=y1-con_font_sz;}
            else { y1+=7; y0-=3; var y2=y1+con_font_sz;}
            if(con.outlet!=inlet and size(src.outlets)>1) {
                cairo.move_to(cr,x+2,y0);
                cairo.show_text(cr,con.outlet);
            }

#check against last_inlet, since we get the connection list in reversed order
#of x position, to only draw the last of a group of connections to the same
#inlet...
#FIXME: this could be made better: instead get the list in normal order,
#and draw the inlet label at the first connection that has enough space after it
#(distance to next connection) to fit the label, or the last one in a group of
#connections if no space was found.
#Also ensure that at least one of the inlets visible connections prints the label.
#And check the connection direction, they should be treated separately.
            if(!con.hide_inlet and last_inlet!=inlet) {
                cairo.move_to(cr,x+4,y1);
                cairo.show_text(cr,inlet);
                last_inlet=inlet;
            }

            cairo.move_to(cr,x+2,y2);            
#            cairo.move_to(cr,x+2,y0+(y1-y0)/2);
            cairo.show_text(cr,con.transfunc_str);
        }
    });
    cairo.restore(cr);
}

# returns a vector of the visible surface numbers of object
# nil means invisible
var obj_visible = func(obj) {
    var view_start = score.time2x(scroll_t);
    var view_end = view_start + canvas_width;
    if(obj.xpos>view_end or obj.xpos+obj.width<view_start) {
        obj.visible=0;
        return [nil,nil];
    }
    obj.visible=1;
    if(view_start<obj.xpos) {
        return [0,nil];
    } else {
        var n1 = int((view_start-obj.xpos)/surf_width);
        var n2 = int((view_end-obj.xpos)/surf_width);
        if(n2==n1 or n2>obj.width/surf_width) n2=nil;
        return [n1,n2];
    }
}

# see if the surface number is already there,
# else mark it for recreation and redraw
var check_surf = func(cr,obj,n) {
    if(n==nil) return;
    var s = obj.gfx_cache[math.mod(n,2)];
    if(s.n!=n) {
        s.n = n;
        s.redraw = 1;
        cairo.surface_destroy(s.surface);
        s.surface = nil;
    }
}

var draw_obj_timegrids = func(cr, obj, start, height) {
    if(!obj.timegrids_enable) return;
    cairo.set_line_width(cr,1);
    var p = 0;
    var y1 = start;
    var y2 = y1+height;
    if(obj.timegrid_pos>0)
        y2 = obj.ypos+obj.height;
    elsif(obj.timegrid_pos<0)
        y1 = obj.ypos;
    foreach(var t;obj.timegrids) {
        var x = int(score.time2x(obj.start+t))+0.5;
        cairo.move_to(cr,x,y1);
        cairo.line_to(cr,x,y2);
        if(p==0) {
            palette.use_style(cr,"obj_time_grid");
            cairo.stroke(cr);
            palette.use_style(cr,"obj_time_grid_weak");
            p = obj.timegrid_pattern-1;
        } else {
            cairo.stroke(cr);
            p -= 1;
        }
    }
    cairo.set_dash(cr,0);
}

var draw_obj_links = func(cr, obj) {
    if(size(obj.links)) {
        cairo.save(cr);
        cairo.translate(cr,0.5,0.5);
        cairo.set_line_width(cr,1);
        palette.use_style(cr,"link");
        foreach(var k;keys(obj.links)) {
            var o = score.objects[k];
            var x = int(score.time2x(obj.start+obj.links[k]));
            var y0 = obj.ypos<o.ypos?obj.ypos:obj.ypos+obj.height;
            var y1 = obj.ypos<o.ypos?o.ypos+o.height:o.ypos;
            cairo.move_to(cr,x,y0);
            cairo.rel_line_to(cr,0,y1-y0);
        }
        cairo.stroke(cr);
        cairo.restore(cr);
    }
}

var draw_obj_labels = func(cr, obj, scroll_x) {
    var x = obj.xpos;
    if(x<scroll_x) x=scroll_x;
    cairo.move_to(cr,x+2,obj.ypos-1);       
    cairo.select_font_face(cr,"Sans");
    cairo.set_font_size(cr,8);
    palette.use_color(cr,"label");

    if(enable_labels) {
        cairo.show_text(cr,obj.get_label());
        cairo.rel_move_to(cr,5,0);
    }
    if(obj.caption!=nil and obj.caption_enable)
        cairo.show_text(cr,obj.caption);
}

var draw_score = func(cr) {
    var obj_keys = keys(score.objects);
    
    # we need to update all this before drawing the connections,
    # since the connection positions is dependant on src objs!
    foreach(var k;obj_keys) {
        var obj = score.objects[k];
        if(obj.sticky)
            obj.xpos = score.time2x(scroll_t);
        else
            obj.xpos = int(score.time2x(obj.start));

        # object needs to update geometry?
        if(obj.remake_surface_flag) {
            obj.update_geometry(cr,canvas_width);
            cairo.surface_destroy(obj.gfx_cache[0].surface);
            obj.gfx_cache[0].surface = nil;
            cairo.surface_destroy(obj.gfx_cache[1].surface);
            obj.gfx_cache[1].surface = nil;
            obj.con_cache = nil;
        }
        
        # we need to check what surfaces are visible
        if(did_scroll or obj.remake_surface_flag) {
            var visible = obj_visible(obj);
            check_surf(cr,obj,visible[0]);
            check_surf(cr,obj,visible[1]);
            foreach(var s;obj.gfx_cache) {
                if(s.n == visible[0] or s.n == visible[1])
                    s.visible=1;
                else {
                    s.visible=0;
                }
            }
        }

        obj.remake_surface_flag=0;
    }    

    foreach(var k;obj_keys) {
        var obj = score.objects[k];

        if(!obj.visible) continue;
        
        draw_obj_timegrids(cr,obj,scroll_y,canvas_height);
        
        foreach(var s;obj.gfx_cache) {
            if(s.n<0) continue;
            s.ofs = s.n*surf_width;
            # should surface be created?
            if(s.surface==nil) {
                if(s.ofs>obj.width) continue;
                if(s.ofs+surf_width <= obj.width)
                    s.width = surf_width;
                else
                    s.width = math.mod(obj.width,surf_width);
                s.last = s.ofs+s.width >= obj.width;
                s.surface = mk_surf(cr,s.width+1,obj.height+1);
                s.redraw=1;
            }
            if(!s.visible) continue;
            # redraw object
            if(s.redraw) {
                s.redraw=0;
                var cr2 = setup_cairo(s.surface);
                obj.draw(cr2,s.ofs,s.width,s.last);
                cairo.destroy(cr2);
            }
            # paint object
            cairo.set_source_surface(cr,s.surface,s.ofs+obj.xpos,obj.ypos);
            cairo.paint(cr);
        }

        draw_obj_links(cr,obj);

        draw_obj_labels(cr,obj,score.time2x(scroll_t));
                
        draw_connections(cr,obj);

        if(enable_unused_reg and !(
            (action.type=="objmove" or action.type=="resize") and
             action.obj.group[obj.id]!=nil)
            ) {
            palette.use_color(cr,"unused_regions");
            foreach(var reg;obj.unused_regions) {
                var x = score.time2x(reg[0]);
                var w = score.time2x(reg[1]);
                cairo.rectangle(cr,x,obj.ypos,w,obj.height);
                cairo.fill(cr);
            }
        }
        
        if(tool_mode=="alignment") {
            cairo.save(cr);
            cairo.translate(cr,0.5,0.5);
            palette.use_color(cr,"alignment");
            cairo.set_line_width(cr,1);
            foreach(var a;obj.get_alignments()) {
                var x = int(score.time2x(obj.start+a));
                cairo.move_to(cr,x,obj.ypos);
                cairo.rel_line_to(cr,0,obj.height);
                cairo.stroke(cr);
            }
            cairo.restore(cr);
        }
        
        if(obj.pending_update) {
            var x2 = int(score.time2x(obj.update_progress));
            var x = (obj.sticky?0:obj.xpos)+x2;
            var w = obj.sticky?score.time2x(score.endmark.time):obj.width;
            cairo.rectangle(cr,x,obj.ypos,w-x2,obj.height);
            palette.use_color(cr,"pending_update");
            cairo.fill(cr);
        }
        
        if(obj == highlighted_obj) {
            cairo.rectangle(cr,obj.xpos,obj.ypos,obj.width,obj.height);
            palette.use_color(cr,"highlight");
            cairo.fill(cr);
        }

        if(obj == edit_obj) {
            cairo.set_line_width(cr,4);
            cairo.rectangle(cr,obj.xpos-2,obj.ypos-2,obj.width+4,obj.height+4);
#            cairo.set_source_rgba(cr,1,0,0,0.2);
            palette.use_color(cr,"edit_outline");
            cairo.stroke(cr);
        } elsif(enable_outlines) {
            cairo.set_line_width(cr,1);
            cairo.rectangle(cr,0.5+obj.xpos,0.5+obj.ypos,obj.width,obj.height);
            palette.use_color(cr,"outline");
            if(obj.is_ghost) palette.use_dash(cr,"ghost");#cairo.set_dash(cr,[2,3]);
            cairo.stroke(cr);
            cairo.set_dash(cr);
        }
    }
    cairo.set_line_width(cr,2);
    cairo.select_font_face(cr,"Sans");
    cairo.set_font_size(cr,8);
    var page = 2;
    foreach(var m;score.marks) {
        var x = int(score.time2x(m.time));
        if(m.type=="page") {
            cairo.move_to(cr,x+2,scroll_y+8);
            palette.use_color(cr,"marks");
            cairo.show_text(cr,"pg "~page);
            page += 1;
        } elsif(m.type=="end") {
            cairo.rectangle(cr,x,scroll_y,canvas_width-x+score.time2x(scroll_t),canvas_height);
            palette.use_color_a(cr,"marks",0.1);
            cairo.fill(cr);
        }
        cairo.move_to(cr,x,scroll_y);
        cairo.rel_line_to(cr,0,canvas_height);
        palette.use_color(cr,"marks");
        cairo.stroke(cr);
    }
    cairo.set_line_width(cr,1);
    if(action.type=="connect") {
        cairo.translate(cr,0.5,0.5);
        cairo.move_to(cr,action.px,action.py);
        cairo.line_to(cr,int(pointer_x+score.time2x(scroll_t)),pointer_y+scroll_y);
#        if(action.con_outlet!=nil) cairo.set_source_rgb(cr,0,0,1);
#        else cairo.set_source_rgb(cr,1,0,0);
        palette.use_color(cr,action.con_outlet!=nil?"connection":"con_error");
        cairo.stroke(cr);
    } elsif(action.type=="resize") {
        var o = action.obj;
        palette.use_color(cr,"resize_box");
        cairo.rectangle(cr,o.xpos,o.ypos,score.time2x(o.length),o.height);
        cairo.fill(cr);
        cairo.translate(cr,0.5,0.5);
        var x = int(score.time2x(o.start+o.length));
        cairo.move_to(cr,x,scroll_y);
        cairo.rel_line_to(cr,0,canvas_height);
        palette.use_color(cr,"move_guide");
        cairo.stroke(cr);
    } elsif(action.type=="align") {
        cairo.translate(cr,0.5,0.5);
        var x = int(score.time2x(action.obj.start+action.align_slave_point));
        var y = int(action.obj.ypos+action.obj.height/2);
        cairo.move_to(cr,x,y);
        cairo.line_to(cr,pointer_x+score.time2x(scroll_t),pointer_y+scroll_y);
#        cairo.set_source_rgb(cr,1,0,1);
        if(action.do_link) {
#            cairo.set_dash(cr,[3,3]);
            palette.use_style(cr,"link");
        } else palette.use_color(cr,"alignment");
        cairo.stroke(cr);
    } elsif(action.type=="objmove") {
        cairo.translate(cr,0.5,0.5);
        var x = int(score.time2x(action.obj.start));
        cairo.move_to(cr,x,scroll_y);
        cairo.rel_line_to(cr,0,canvas_height);
        palette.use_color(cr,"move_guide");
        cairo.stroke(cr);
    } elsif(action.type=="insert") {
        var x = action.px-score.time2x(scroll_t);
        cairo.rectangle(cr,action.px,scroll_y,pointer_x-x,canvas_height);
        palette.use_color(cr,"insert");
        cairo.fill(cr);
    }
    if(flash_align!=nil) {
        cairo.translate(cr,0.5,0.5);
        cairo.move_to(cr,flash_align[0],flash_align[1]);
        cairo.line_to(cr,flash_align[0],flash_align[2]);
#        cairo.set_source_rgba(cr,1,0,1,0.5);
        palette.use_color(cr,"alignment");
        cairo.stroke(cr);
    }
    did_scroll = 0;
}

# set scroll_t for each page
# set zoom, as in set_zoom() but without redrawing...

var get_page_lengths = func {
    var v = [];
    score.sort_marks();
    var last = 0;
    foreach(var m;score.marks) {
        if(m.type=="page") {
            append(v,m.time-last);
            last = m.time;
        }
    }
    var end_t = score.endmark.time;
    if(last<end_t) append(v,end_t-last);
    return v;
}

var print_opts = [
    { name:"format", label:"File format", type:"combobox",
      choices:["pdf","ps","svg"],
      value:"pdf",
      callback:func(o,opts) {
        var fn = opts.file['new_value'];
        if(fn==nil) fn=opts.file.value;
        var s = split(".",fn);
        s[-1]=o.new_value;
        fn=s[0];
        for(var i=1;i<size(s);i+=1)
            fn~="."~s[i];
        opts.file.set(fn);
      },
      group:"Output",
    },
    { name:"file", label:"Export to file:", type:"filechooser",
#          value:unix.getcwd() ~ "/newprint.pdf", action:"save", group:"Output",
      value:nil, action:"save", group:"Output",
    },
    { name:"pagenums", label:"Page numbers", type:"toggle", value:1, group:"Output"},
    { name:"title_all",label:"Title on all pages",type:"toggle",value:1,group:"Output"},
    { name:"subtitle_all",label:"Subtitle on all pages",type:"toggle",value:0,group:"Output"},
    { name:"composer_all",label:"Composer on all pages",type:"toggle",value:0,group:"Output"},
    { name:"min_height",label:"Minimum score height",type:"spinbutton",value:400,max:9999,min:1,group:"Output"},
    { name:"padding",label:"Y padding",type:"spinbutton",value:20,max:999,min:1,group:"Output"},
    { name:"pagesize", label:"Page Size", type:"combobox",
      choices:["A3","A4","A5","Custom"],
      value:"A4",
      callback:func(o,opts) {
        if(o.new_value=="Custom") {
            opts.pagew.enable(1);
            opts.pageh.enable(1);
            return;
        }
        var sizes = {
            A3:[842,1191],
            A4:[595,842],
            A5:[420,595],
        };
        var sz = sizes[o.new_value];
        opts.pagew.set(sz[0]);
        opts.pageh.set(sz[1]);
        opts.pagew.enable(0);
        opts.pageh.enable(0);
      },
      group:"Page",
    },
    { name:"pagew", label:"Page width", type:"spinbutton",
      max:9999, value:595, enabled:0, group:"Page",
    },
    { name:"pageh", label:"Page height", type:"spinbutton",
      max:9999, value:842, enabled:0, group:"Page",
    },
    { name:"xmarg", label:"X margin", type:"spinbutton", max:999,
      value:20, group:"Page",
    },
    { name:"ymarg", label:"Y margin", type:"spinbutton", max:999,
      value:40, group:"Page",
    },
    { name:"landscape", label:"Landscape", type:"toggle", value:1,
      group:"Page",
    },
];

var print_dialog = func {
    foreach(var o;print_opts) {
        if(o.name=="file" and o.value==nil) {
            o.value="newprint.pdf";
        }
    }
    optbox.open("Print to file",print_opts,func(x) {
        if(x==nil) return;
        print_to_file(optbox.value_hash(x));
        return 0;
    });
}

var print_to_file = func(opt) {
    var page_w = opt.landscape?opt.pageh:opt.pagew;
    var page_h = opt.landscape?opt.pagew:opt.pageh;
    var t_h = options.get("timeline_height");
    var page_lengths = get_page_lengths();
    var hmargin = opt.xmarg;
    var vmargin = opt.ymarg;
    var y_range = get_y_range();
    var score_height = y_range[1]-y_range[0];
    var y_ofs = y_range[0];
    var padding = opt.padding;
    if(score_height<opt.min_height) {
        score_height=opt.min_height;
#        y_ofs = opt.min_height/2 - score_height/2;
    }
    var surf = nil;
    var cr = nil;

    var init_page = func(fn) {
        print("Printing to file ",fn,"\n");
        surf = cairo[opt.format ~ "_surface_create"](fn,page_w,page_h);
        cr = cairo.create(surf);
        cairo.set_line_join(cr,cairo.LINE_JOIN_ROUND);
    #    cairo.set_line_cap(cr,cairo.LINE_CAP_ROUND);
        cairo.set_line_width(cr,1);
    }

    if(opt.format!="svg") init_page(opt.file);
    else {
        var last_dot = nil;
        for(var i=0;i<size(opt.file);i+=1)
            if(opt.file[i]==`.`) last_dot=i;
        if(last_dot) opt.file = substr(opt.file,0,last_dot);
    }

    var scale = (page_h-vmargin*2)/(score_height+t_h+padding*2);
#    var scale = (page_h-vmargin*2-t_h)/(score_height);
    var work_w = (page_w-hmargin*2)/scale;
    var work_h = (page_h-vmargin*2)/scale;

    var save_scroll = scroll_t;
    var save_zoom = score.zoom;

    scroll_t = 0;
    var pg_num = 1;
    var n_pages = size(page_lengths);
    progress.start("Printing...");
    foreach(var page_len;page_lengths) {
        if(opt.format=="svg") {
            var fn = opt.file~"-"~pg_num~".svg";
            init_page(fn);
        }
    
       # print("page length: ",page_len," s\n");
        score.zoom = work_w/page_len;
        lskip = 0;

        palette.use_color(cr,"fg");
        cairo.select_font_face(cr,"Sans");

        cairo.set_font_size(cr,14);
        var ext = cairo.text_extents(cr,score.metadata.title);
        var y = vmargin/2 + ext.height/2;
        
        if(opt.title_all or pg_num==1) {
            cairo.move_to(cr,page_w/2 - ext.x_advance/2, y);
            cairo.show_text(cr,score.metadata.title);
        }
        
        if(opt.subtitle_all or pg_num==1) {
            cairo.set_font_size(cr,9);
            var ext = cairo.text_extents(cr,score.metadata.subtitle);
            cairo.move_to(cr,page_w/2 - ext.x_advance/2, y+ext.height+2);
            cairo.show_text(cr,score.metadata.subtitle);
        }
        
        if(opt.composer_all or pg_num==1) {
            var ext = cairo.text_extents(cr,score.metadata.composer);
            cairo.move_to(cr,page_w - ext.x_advance - hmargin, y+ext.height+2);
            cairo.show_text(cr,score.metadata.composer);
        }
        
        if(opt.pagenums) {
            cairo.set_font_size(cr,9);
            var ext = cairo.text_extents(cr,pg_num);
            cairo.move_to(cr,page_w/2 - ext.x_advance/2, page_h - vmargin/2 + ext.height/2);
            cairo.show_text(cr,pg_num);
        }
        
        cairo.save(cr);
        cairo.translate(cr,hmargin,vmargin);
        cairo.rectangle(cr,-0.5,-0.5,1+page_w-hmargin*2,1+page_h-vmargin*2);
        cairo.clip(cr);
        cairo.scale(cr,scale,scale);
        redraw_timegrid(cr,1,work_w,work_h);
        cairo.translate(cr,-score.time2x(scroll_t),-y_ofs+t_h+padding);

        # we need to do this to reflect zoom changes, and we must
        # do it in a separate loop since connection positions is
        # dependant on src-obj pos and widths...
        foreach(var k;keys(score.objects)) {
            var obj = score.objects[k];
            var scroll_x = score.time2x(scroll_t);
            if(obj.sticky) obj.xpos = scroll_x;
            else           obj.xpos = int(score.time2x(obj.start));

            obj.visible = (obj.xpos<scroll_x+work_w or obj.xpos+obj.width>=scroll_x);

            obj.update_geometry(cr,work_w);
            obj.con_cache = nil;
        }

        foreach(var k;keys(score.objects)) {
            var obj = score.objects[k];
            if(!obj.visible) continue;
            draw_obj_timegrids(cr,obj,y_ofs-padding,work_h);
            cairo.save(cr);
            cairo.translate(cr,obj.xpos,obj.ypos);
            cairo.set_line_width(cr,1);
            cairo.set_dash(cr,0);
            palette.use_color(cr,"fg");
            obj.draw(cr,0,obj.width,1);
            cairo.restore(cr);
            draw_obj_links(cr,obj);
            draw_obj_labels(cr,obj,0);
            draw_connections(cr,obj);
        }
        cairo.restore(cr);
        cairo.show_page(cr);
        if(opt.format=="svg") cairo.surface_finish(surf);
        progress.update(pg_num/n_pages);
        pg_num += 1;
        scroll_t += page_len;
    }
    if(opt.format!="svg") cairo.surface_finish(surf);
    progress.done();
    cairo.destroy(cr);
    
    scroll_t = save_scroll;
    score.zoom = save_zoom;
    lskip = 0;
    foreach(var k;keys(score.objects))
        score.objects[k].remake_surface();
       
    canvas.queue_draw();
}

var canvas_expose = func(wid,ev) {
    if(ev.count!=0) return 1;
    var cr = wid.cairo_create();
    palette.use_color(cr,"bg");
    cairo.paint(cr);
    cairo.save(cr);
    cairo.set_line_width(cr,1);
    cairo.translate(cr,0.5,0.5);
    redraw_timegrid(cr,0,canvas_width,canvas_height);
    cairo.restore(cr);

    cairo.set_line_width(cr,1);    
    cairo.move_to(cr,int(score.time2x(playpos-scroll_t))+0.5,0);
    cairo.rel_line_to(cr,0,canvas_height);
    palette.use_color(cr,"playcursor");
    cairo.stroke(cr);
    cairo.move_to(cr,int(score.time2x(locate_pos-scroll_t))+0.5,0);
    cairo.rel_line_to(cr,0,canvas_height);
    palette.use_color(cr,"locatecursor");
    cairo.stroke(cr);
    
#    cairo.rectangle(cr,0,0,canvas_width,canvas_height);
#    cairo.clip(cr);
    cairo.translate(cr,int(-score.time2x(scroll_t)),-int(scroll_y));
    draw_score(cr);
    cairo.destroy(cr);
    return 1;
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
        var tg = score.time2x(1); # pixels per one second
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

    # this could probably be done in a simpler way...
    if(scroll_t==0) {
        var lx = var gx = var s = 0;
    } else {
        var lx = score.time2x(-math.mod(scroll_t,lskip));
        var gx = score.time2x(-math.mod(scroll_t,gskip));
        var s = int(scroll_t);
        s -= math.mod(s,lskip);
    }
    if(gx<0) gx+=gdx;
    if(lx<0) { lx+=ldx; s+=lskip; }

    if(do_labels) {
        for(var n=lx;int(n)<=width;n+=ldx) {
            cairo.move_to(cr,int(n),0);
            cairo.rel_line_to(cr,0,ypad);
#            cairo.set_source_rgb(cr,0.6,0.6,0.6);
            palette.use_style(cr,"time_grid2");
            cairo.stroke(cr);

            var min = int(s/60);
            var sec = math.mod(s,60);
            if(sec>=0) {
                if(sec==0) {
                    cairo.set_font_size(cr,time_font_sz*1.5);
                    var txt = min~"'";
                } else {
                    cairo.set_font_size(cr,time_font_sz);
                    var txt = min~"'"~sec;
                }
                cairo.move_to(cr,int(n+1),ypad);
    #            cairo.set_source_rgb(cr,0,0,0);
                palette.use_color(cr,"time_label");
                cairo.show_text(cr,txt);
            }
            s += lskip;
        }
    } else {
        ypad = 0;
    }
#    var i = math.mod(int(scroll_t),lskip);
#    if(scroll_t>0) i+=1;
    for(var n=gx;int(n)<=width;n+=gdx) {
        cairo.move_to(cr,int(n),ypad);
        cairo.rel_line_to(cr,0,height-ypad);
#        if(i==lskip) {
#            palette.use_style(cr,"time_grid2");
#            i=0;
#        } else
            palette.use_style(cr,"time_grid");
#        i += 1;
        cairo.stroke(cr);
    }
    cairo.set_dash(cr,0);
}

var repaint = func {
    timeline_canvas.queue_draw();
    canvas.queue_draw();
}

var highlight_object = func(obj) {
    highlighted_obj = obj;
    canvas.queue_draw();
}

var flash_align = nil;

var action = {};
action.type = nil;
action.obj = nil;
action.px = 0;
action.py = 0;
action.con_outlet = nil;
action.start = func(type,o=nil,ev=nil) {
    if(me.type!=nil) return;
    me.type = type;
    me.px = pointer_x+score.time2x(scroll_t);
    me.py = pointer_y+scroll_y;
    
    if(type=="objmove") {
        highlight_object(o);
        me.obj = o;
        me.old_y = o.ypos;
        me.old_start = o.start;
        canvas.set_cursor(gtk.GDK_FLEUR);
    } elsif(type=="resize") {
        highlight_object(o);
        me.obj = o;
        me.resize_edge = 
            me.px > o.xpos+o.width/2 
            or size(me.obj.group)>1
            or me.obj.fixed_start
            ? "r":"l";
        canvas.set_cursor(me.resize_edge=="r"?gtk.GDK_RIGHT_SIDE:gtk.GDK_LEFT_SIDE);
    } elsif(type=="connect") {
        highlight_object(o);
        var outlets = sort(keys(o.outlets),cmp);
        do_connect_menu(o.get_label()~" outlets",outlets,func(x) {
            if(x!=nil) {
                me.obj = o;
                me.con_outlet = x!=""?x:nil;
                canvas.set_cursor(gtk.GDK_CIRCLE);
            } else {
                me.type = nil;
                highlight_object(nil);
            }
        },1);
    } elsif(type=="conmove") {
        me.obj = o[0];
        me.con = o[1];
        me.inlet = o[2];
        canvas.set_cursor(gtk.GDK_SB_H_DOUBLE_ARROW);
    } elsif(type=="markmove") {
        me.mark = o;
        canvas.set_cursor(gtk.GDK_SB_H_DOUBLE_ARROW);
    } elsif(type=="align") {
        highlight_object(o);
        me.obj = o;
        me.align_src = nil;

        canvas.set_cursor(gtk.GDK_CROSS);

        # 1 = add link, 2 = remove link
        if(ev.state['shift-mask']==1) me.do_link=2;
        elsif(btn3(ev)) me.do_link=1;
        else me.do_link=0;

        if(ev.state['control-mask']==1) {
            me.do_align=0;
            me.do_link=1;
        } else me.do_align=1;
        
        if(ev.state['mod1-mask']!=1) {
            var a = alignment_at_pointer(o);
            me.align_resize = 0;
            if(a==nil) {
                me.type = nil;
                highlight_object(nil);
            } else {
                me.align_slave_point = a;
            }
        } else {
            var a = alignment_at_pointer(o,1);
            me.align_slave_point = a;
            me.align_resize = 1;
        }
    } elsif(type=="insert") {
        canvas.set_cursor(gtk.GDK_SB_H_DOUBLE_ARROW);
        me.selection = [];
        foreach(var k;keys(score.objects)) {
            var o = score.objects[k];
            if(o.xpos>me.px and o.fixed_start!=1)
                append(me.selection,o);
        }
    }
}
action.motion = func(ev) {
    if(me.type=="objmove") {
        var g = me.obj.group;
        foreach(var k;keys(g)) {
            var o = g[k];
            if(ev.state['shift-mask']!=1 and o.fixed_start!=1) {
                o.start += score.x2time(ev.x-pointer_x);
#                o.start = me.old_start + scroll_t+score.x2time(ev.x-me.px);
                #FIXME: we only need to update the con_positions,
                #and dirty-mark the con_cache at objmove done.
#                foreach(var k2;keys(o.children))
#                    o.children[k2].con_cache = nil;
#                o.con_cache = nil;
            }
        }
        if(ev.state['control-mask']!=1)
#            me.obj.ypos = me.old_y + scroll_y + int((ev.y-me.py)/y_grid)*y_grid;
            me.obj.ypos = me.old_y + int((ev.y+scroll_y-me.py)/y_grid)*y_grid;
        canvas.queue_draw();
    } elsif(me.type=="resize") {
        var dx = score.x2time(ev.x-pointer_x);
        if(me.resize_edge=="l") {
            me.obj.start = me.obj.start + dx;
            me.obj.length = me.obj.length - dx;
        } else
            me.obj.length = me.obj.length + dx;
        canvas.queue_draw();
    } elsif(me.type=="conmove") {
#        me.obj.draw_pos = scroll_t + score.x2time(ev.x);
        me.con.draw_pos = scroll_t + score.x2time(ev.x) - me.obj.start;
        update_con_pos(me.obj,me.con);
        canvas.queue_draw();
    } elsif(me.type=="markmove") {
        me.mark.time = scroll_t + score.x2time(ev.x);
        canvas.queue_draw();
    } elsif(me.type=="connect") {
        canvas.queue_draw();
    } elsif(me.type=="align") {
        canvas.queue_draw();
    } elsif(me.type=="pan") {
        scroll_adj.set("value",me.py-ev.y);
        time_scroll_adj.set("value",score.x2time(me.px-ev.x));
    } elsif(me.type=="insert") {
        foreach(var o;me.selection) {
            o.start = o.start + score.x2time(ev.x-pointer_x);
        }
        canvas.queue_draw();
    }
}
action.end = func {
    canvas.set_cursor(nil);
    if(me.type==nil) return;
    if(me.type=="objmove") {
        var g = me.obj.group;
        var max_adj = 0;
        foreach(var k;keys(g)) {
            var obj = g[k];
            var adj = 0 - obj.start;
            if(adj>max_adj) max_adj=adj;
        }
        var x = score.hold_update();
        
        foreach(var k;keys(g)) {
            var obj = g[k];
            if(!obj.fixed_start) obj.start += max_adj;
#            if(me.obj.ypos!=me.old_y or me.obj.start!=me.old_start)
            if(me.obj.start!=me.old_start) {
#                print("start != old_start\n");
                obj.move_done();
            }

            obj.con_cache = nil;
            foreach(var k2;keys(obj.children))
                obj.children[k2].con_cache = nil;

        }
        score.unhold_update(x,g);
        
        highlight_object(nil);
        me.obj = nil;
    } elsif(me.type=="resize") {
        if(size(me.obj.group)>1) {
            var mt = me.obj.get_link_max_t();
            if(me.obj.length<mt) me.obj.length=mt;
        }
        me.obj.move_resize_done(me.resize_edge=="l"?1:0,1);
        highlight_object(nil);
        me.obj = nil;
    } elsif(me.type=="insert") {
        var max_adj = 0;
        foreach(var o;me.selection) {
            var adj = 0 - o.start;
            if(adj>max_adj) max_adj=adj;
        }
        foreach(var o;me.selection) {
            if(!o.fixed_start) o.start += max_adj;
            o.move_done();
        }
        set_tool('object');
    } elsif(me.type=="connect") {
        var o = obj_at_pointer();
        if(o!=nil and o!=me.obj) {
            highlight_object(o);

#            if(me.con_outlet=="(depend)")      # this is ugly...
#                var inlets = ["(depend)"];
#            else
                var inlets = me.con_outlet!=nil ?
                             o.get_unconnected_inlets(me.obj,me.con_outlet)
                           : o.get_connected_inlets(me.obj);
            var title = (me.con_outlet!=nil ? 
                         me.obj.get_label()~":"~me.con_outlet
                       : "disconnect "~me.obj.get_label())~"->"~o.name~" inlet";
            if(size(inlets)) {
                do_connect_menu(title,inlets,func(x) {
                    if(x!=nil) {
                        if(me.con_outlet!=nil)
                            o.connect(me.obj, me.con_outlet, x);
                        else
                            o.disconnect(me.obj, x);
                    }
                    me.obj = me.con_outlet = nil;
                    highlight_object(nil);
                });
            } else {
                highlight_object(nil);
#                canvas.queue_draw();
            }
        } else {
            me.obj = me.con_outlet = nil;
            highlight_object(nil);
#            canvas.queue_draw();
        }
    } elsif(me.type=="conmove") {
        me.obj.con_cache = nil;
        me.obj = nil;
    } elsif(me.type=="markmove") {
        me.mark = nil;
        score.sort_marks();
    } elsif(me.type=="align") {
        var o = obj_at_pointer();
        if(o!=nil and me.do_link==2) {
            me.obj.remove_link(o);
            me.obj = nil;
            set_tool('object');
        } elsif(o!=nil and me.do_align==0) {
            me.obj.add_link(o,me.align_slave_point);
            me.obj = nil;
            set_tool('object');
        # if the objects group are not the same, or if the objects are alread linked
        } elsif(o!=nil and (o.group!=me.obj.group or size(me.obj.group)<2 or me.obj.is_linked(o))) {
            var a = alignment_at_pointer(o);
            if(a!=nil) {
                if(me.align_resize) {
                    if(me.align_slave_point>0) { # or me.obj.fixed_start) {
                        #right edge
                        var l = a - (me.obj.start-o.start);
                        var s = me.obj.start;
                        me.align_slave_point = l;
                    } else {
                        #left edge
                        var l = me.obj.length + (me.obj.start-o.start-a);
                        var s = o.start+a;
                    }
                    if(l>0) {
                        me.obj.length = l;
                        me.obj.start = s;
                    }
                    me.obj.move_resize_done(me.align_slave_point>0?0:1,1);
                } else {
#                    me.obj.start = o.start+a-me.align_slave_point;
#                    if(me.obj.start<0) me.obj.start=0;
                    var max_adj = 0;
                    foreach(var k;keys(me.obj.group)) {
                        var obj = me.obj.group[k];
                        if(!obj.fixed_start) obj.start = o.start+a-me.align_slave_point;
                        if(obj.start<max_adj) max_adj=obj.start;
                    }
                    foreach(var k;keys(me.obj.group)) {
                        var obj = me.obj.group[k];
                        if(!obj.fixed_start) obj.start -= max_adj;
                        me.obj.move_done();
                    }
                    if(me.obj==o) a=me.align_slave_point; #for the flash only..
                }
                flash_align = [
                    int(score.time2x(o.start+a)),
                    me.obj.ypos<o.ypos?me.obj.ypos:me.obj.ypos+me.obj.height,
                    me.obj.ypos<o.ypos?o.ypos+o.height:o.ypos];
                gtk.timeout_add(1000, func {
                    flash_align = nil;
                    canvas.queue_draw();
                    return 0;
                });
                if(me.do_link==1) {
                    me.obj.add_link(o,me.align_slave_point);
                }
                me.obj = nil;
                set_tool('object');
            }
        }
        highlight_object(nil);
#        canvas.queue_draw();
    }
    me.type = nil;
    canvas.queue_draw();
}

#var auto_scroll_xofs = 0;
var auto_scrolling = 0;
var auto_scroll = func(ev) {
    if(pointer_x>canvas_width) {
#        action.px -= (pointer_x-canvas_width);
        time_scroll_adj.set("value",scroll_t+score.x2time(pointer_x-canvas_width));
        ev.x += pointer_x-canvas_width; #this doesnt work... :(
        print(ev.x,"\n");
        action.motion(ev);
#        auto_scroll_xofs = pointer_x-canvas_width;
    } elsif(pointer_x<0) {
        time_scroll_adj.set("value",scroll_t+score.x2time(pointer_x));
    } else {
        auto_scrolling = 0;
        return 0;
    }
    return 1;
}

var canvas_motion = func(wid, ev) {

    # we do a new search when the pointer is outside the old objects region...
    # but when it's not over any object, there is a search for each motion event!
    # this is totally inefficient and needs to be done in a better way!
    # but how? perhaps cache the largest empty rectangle, but how do we calculate this?
    # we can also have a timeout, so we only do it when the pointer hasn't moved for N time..
    # anyhow, the only reason to do this is for visual highlight on pointer hover...
#    var o = highlighted_obj;
#    if(o == nil or ev.x < o.xpos or ev.x > o.xpos+o.width
#            or ev.y < o.ypos or ev.y > o.ypos+o.height)
#        highlight_object(obj_at_xy(ev.x,ev.y));
    var x = ev.x;
    var y = ev.y;

    if(edit_obj!=nil) {
        ev.x -= edit_obj.xpos - score.time2x(scroll_t);
        ev.y -= edit_obj.ypos - scroll_y;
#        if(ev.x>=0 and ev.y>=0 and ev.x<edit_obj.width and ev.y<edit_obj.height)
            edit_obj.edit_event(ev);
    } else
        action.motion(ev);

    if(action.type!=nil and auto_scrolling==0) {
        if(x > canvas_width or x < 0) {
            auto_scrolling = 1;
#            time_scroll_adj.set("value",score.x2time(x-action.px));
##            gtk.timeout_add(100,auto_scroll,ev);
#        if(y > canvas_height or y < 0)
#            scroll_adj.set("value",y-action.py);
        }
    }

    pointer_x = x;
    pointer_y = y;
}

var alignment_at_pointer = func(obj,edges_only=0) {
    var found = nil;
    var min_dx = nil;
    var px = pointer_x + score.time2x(scroll_t-obj.start);
    var algn = obj.get_alignments();
    if(obj.fixed_start and edges_only) return algn[-1];
    if(edges_only) algn = [algn[0],algn[-1]];
    foreach(var a;algn) {
        var dx = math.abs(px-score.time2x(a));
        if(min_dx==nil or dx<min_dx) {
            min_dx=dx;
            found=a;
        }
    }
    return found;
}

var con_at_pointer = func {
    var px = pointer_x + score.time2x(scroll_t);
    var py = pointer_y + scroll_y;
    var found = nil;
    foreach(var k; keys(score.objects)) {
        var obj = score.objects[k];
        for_each_con(obj, func(con,inlet,x,y0,y1) {
            if(y0>y1) { var t=y0; y0=y1; y1=t; }
            if(py > y0 and py < y1 and px > x-4 and px < x+4) {
                found = [obj,con,inlet];
            }
        });
    }
    return found;
}

var mark_at_pointer = func {
    var px = pointer_x + score.time2x(scroll_t);
    foreach(var m;score.marks) {
        var x = score.time2x(m.time);
        if(px > x-4 and px < x+4)
            return m;
    }
    return nil;
}

var obj_at_xy = func(x,y) {
    x += score.time2x(scroll_t);
    y += scroll_y;
    foreach(var k; keys(score.objects)) {
        var obj = score.objects[k];
#        if(x >= obj.xpos and x <= obj.xpos+obj.width
#            and y >= obj.ypos and y <= obj.ypos+obj.height)
        if(obj.xy_inside(x,y)) return obj;
    }
    return nil;
}

var obj_at_pointer = func obj_at_xy(pointer_x,pointer_y);

timeline_canvas.connect("expose-event",timeline_expose);
timeline_canvas.connect("configure-event",timeline_configure);

var open_props = func {
        var o = obj_at_pointer();
        if(o!=nil) propbox.edit_props(o.get_label(),o.properties,o.clean_globals(new_nasal_env()));
        else {
            var c = con_at_pointer();
            if(c!=nil) propbox.edit_props(
                c[1].srcobj.get_label()~":"~c[1].outlet~"->"
                ~c[0].get_label()~":"~c[2],
                c[1].properties);
            else
                edit_score_props();
        }
}

var handle_key = {};
var handle_button = {};
handle_key.object = func(ev) {
    var k = ev.keyval_name;
#    print(k,"\n");
    if(k=='n') create_object();
    elsif(k=='Delete' or k=='BackSpace') {
        if(action.type=="objmove") {
            action.obj.destroy();
            action.end();
            canvas.queue_draw();
        } elsif(action.type=="conmove") {
            action.obj.disconnect(action.con.srcobj,action.inlet);
            canvas.queue_draw();
        } elsif(action.type=="markmove") {
            score.delete_mark(action.mark);
            canvas.queue_draw();
        }
    } elsif(k=='period') action.start("connect",obj_at_pointer());
#    elsif(k=='a') action.start("align",obj_at_pointer());
    elsif(k=='p') {
        open_props();
    } elsif(k=='e') {
        var o = obj_at_pointer();
        if(o!=nil) {
            edit_obj = o.edit_start()?o:nil;
            canvas.queue_draw();
        }# else {
#            set_endmark(scroll_t+score.x2time(pointer_x))
 #       }
    } elsif(k=='u') {
        var o = obj_at_pointer();
#        var x = score.delay_update;
#        score.delay_update = 0;
        if(o!=nil) o.update(-1);
#        score.delay_update = x;
    } elsif(k=='I') {
        inspector.inspect(obj_at_pointer());
    }
}
handle_key.alignment = handle_key.copy = handle_key.insert = func(ev) {
    if(ev.keyval_name=='Escape') set_tool("object");
}

handle_button.object = func(ev) {
#    print("object button press\n");
    if(action.type=="connect") {
        action.end();
        return;
    }
    
    if(ev.type=="2button-press" and ev.state["control-mask"]==1) {
        open_props();
        return;
    }

    var c = con_at_pointer();
    if(c!=nil) {
        action.start("conmove",c);
        return;
    }
    var m = mark_at_pointer();
    if(m!=nil) {
        action.start("markmove",m);
        return;
    }
    var o = obj_at_pointer();
    if(o!=nil) {
        if(ev.type=="2button-press") {
            action.end();
            edit_obj = o.edit_start()?o:nil;
            canvas.queue_draw();
            return;
        }
        if(o==edit_obj) {
            ev.x -= o.xpos - score.time2x(scroll_t);
            ev.y -= o.ypos - scroll_y;
            o.edit_event(ev);
            return;
        }
        if(ev.button==1 and edit_obj==nil) {
            if(ev.state["mod1-mask"]==1) action.start("resize",o);
            else action.start("objmove",o);
        } elsif(btn3(ev))
            action.start("connect",o);
    } elsif(btn3(ev)) {
        create_object();
        return;
    }
    if(edit_obj!=nil) {
        edit_obj.edit_end();
        edit_obj=o==nil?nil:(o.edit_start()?o:nil);
        canvas.queue_draw();
        return;
    }

}

handle_button.alignment = func(ev) {
    var o = obj_at_pointer();
    if(o==nil) return;
    action.start("align",o,ev);
}

handle_button.copy = func(ev) {
    var o = obj_at_pointer();
    if(o==nil) return;
    var o2 = o.duplicate(btn3(ev));
    action.start("objmove",o2);
    set_tool("object");
}

handle_button.insert = func(ev) {
    action.start("insert");
}

var canvas_press = func(wid, ev) {
#    canvas.grab_focus(); #didn't help..
    if(ev.button==2) {
        action.start("pan");
        return;
    }
    handle_button[tool_mode](ev);
}

var zoom_step = func(x) {
    var z = zoom_adj.get("value");
#    zoom_adj.set("value",z*math.pow(2,-x));
    zoom_adj.set("value",z-x*0.2);
}

var locate = func(t) {
    if(t<0) t=0;
    locate_pos = t;
    playbus.locate(t);
    if(!playstate) set_playpos(t);
}

var set_endmark = func(t) {
    score.endmark.time = t;
    score.sort_marks();
    time_scroll_adj.set("upper",t);
    canvas.queue_draw();
}

var add_pagemark = func(t) {
    score.add_mark("page",t);
    canvas.queue_draw();
}

var canvas_key = func(wid, ev) {
    var k = ev.keyval_name;
#    print(k," pressed\n");
#    if(contains(tool_keys,k)) {
#        set_tool(tool_keys[k]);
#        return;
#    }
    if(check_tool_key(k)) return;
    
    if(k=='1')       zoom_fit_all();
    elsif(k=='plus') zoom_step(1);
    elsif(k=='minus') zoom_step(-1);
    elsif(k=='O') outlines_toggle.clicked();
    elsif(k=='L') labels_toggle.clicked();
    elsif(k=='Home') scroll_home();
    elsif(k=='space') playbutton.clicked();
    elsif(k=='Return') locate(scroll_t+score.x2time(pointer_x));
    elsif(k=='0') locate(0);
    elsif(k=='U') delay_update_toggle.clicked();
#    elsif(k=='U') update_button.clicked();
    elsif(k=='E') set_endmark(scroll_t+score.x2time(pointer_x));
    elsif(k=='b') add_pagemark(scroll_t+score.x2time(pointer_x));
    else
        handle_key[tool_mode](ev);
}

canvas.set("events",
    {"button-press-mask":1,
     "button-release-mask":1,
     "pointer-motion-mask":1,
     "pointer-motion-hint-mask":1,
     "key-press-mask":1,
     "enter-notify-mask":1},
     "can-focus",1
);
canvas.connect("expose-event",canvas_expose);
canvas.connect("configure-event",canvas_configure);
canvas.connect("motion-notify-event",canvas_motion);
canvas.connect("enter-notify-event",func canvas.grab_focus());
canvas.connect("button-press-event",canvas_press);
canvas.connect("button-release-event",func(wid,ev) {
    if(edit_obj!=nil) edit_obj.edit_event(ev);
    else action.end();
});
canvas.connect("key-press-event",canvas_key);

time_scroll_adj.connect("value-changed",func(wid) {
#    scroll_t = int(wid.get("value"));
    scroll_t = wid.get("value");
    did_scroll = 1;
    repaint();
});

var goto_now = func { #FIXME
    var t = playpos;
    t -= score.x2time(canvas_width*0.9);
    if(t<0) t=0;
    time_scroll_adj.set("value",t);
}

var create_object_win = nil;
var make_create_object_win = func {
    var store = gtk.ListStore_new("gchararray");
    var view = gtk.TreeView("model",store);
    var c = gtk.TreeViewColumn("title","Classes","expand",1);
    c.add_cell(gtk.CellRendererText(),0,"text",0);
    view.append_column(c);
    
    var desc = gtk.Label("xalign",0,"yalign",0,"xpad",4,"ypad",4,"wrap",1,"use-markup",1);
#    var desc_frame = gtk.Frame("label","description");
#    desc_frame.add(desc);
    
    var classes = algoscore.get_classes();

    foreach(v;sort(keys(classes),cmp))
        store.set_row(store.append(),0,v);
        
#    var close = func { w.hide(); w.destroy(); }
    var close = func { w.hide(); }
    
    view.connect("row-activated",func(wid,path,col) {
        var name = store.get_row(path,0);
        var obj = score.new_obj_by_name(name);
#        obj.update();
        if(!obj.fixed_start) obj.start = scroll_t + score.x2time(pointer_x);
#        obj.ypos = int(scroll_y + pointer_y);
        obj.ypos = int((scroll_y+pointer_y)/y_grid)*y_grid;
#        obj.ypos = scroll_y+int(pointer_y/y_grid)*y_grid;
        obj.move_done();
#        did_scroll = 1;
        obj.remake_surface();
        close();
    });
    
    view.connect("key-press-event",func(wid,ev) {
        if(ev.keyval_name=="Escape") close();
        return 0;
    });
    
    view.get_selection().connect("changed",func(wid) {
        var row = wid.get_selected();
        if(row==nil) return;
        var name = store.get_row(row,0);
        desc.set("label",classes[name].description);
    });

    var w = gtk.Window("title","Create object","default-height",500,
        "border-width",4,"window-position","mouse","transient-for",globals.top_window);
#    var w = gtk.Window("title","Create object");
    create_object_win = w;

    w.connect("delete-event",close);
    var sc = gtk.ScrolledWindow("hscrollbar-policy","never");
    sc.add(view);
    var box = gtk.HBox("spacing",4);
    box.pack_start(sc,0);
    box.pack_start(desc);
    w.add(box);
    w.show_all();
}

var create_object = func {
    if(create_object_win==nil)
        make_create_object_win();
    else {
        create_object_win.show_all();
        create_object_win.raise();
    }
}
#gtk.timeout_add(500,func {
#    if(follow_now) goto_now();
##    elsif(follow_now==2) set_zoom(1);
##    if(follow_now!=0) canvas.queue_draw();
#    return 1;
#});

#var print_dialog = func {
#    var d = gtk.FileChooserDialog("title","Print to file","action","save");
#    d.add_buttons("gtk-cancel",-2,"gtk-ok",-3);
#    d.connect("response",func(wid,id) {
#        if(id==-3) {
#            print_to_file(d.get_filename());
#            d.hide();
#            d.destroy();
#        } elsif(id==-2) {
#            d.hide();
#            d.destroy();
#        }
#    });
#    d.show();
#    print_to_file();
#}

#var topwindow = nil;
var init = func {
#var init = func(newscore=nil) {
#    if(newscore!=nil) print("score_ui.init called with newscore\n");
    set_tool("object");
#    score = newscore==nil?algoscore.Score.new():newscore;
    score = algoscore.Score.new();
    score.set_queue_draw(func canvas.queue_draw());
    set_playpos(0);
    time_scroll_adj.set("upper",score.endmark.time);
    canvas.queue_draw();
#    topwindow = w;
#    propbox.set_topwindow(w);
    return box;
}

var endmark_to_last = func {
    var last_t = 0;
    foreach(var k;keys(score.objects)) {
        var obj = score.objects[k];
        var end = obj.start+obj.length;
        if(end>last_t) last_t=end;
    }
    if(last_t==0) last_t=10;
    set_endmark(last_t);
}
var update_pending = func update_button.clicked();
var get_score = func score;
var edit_score_props = func {
    propbox.edit_props("score",score.properties);
}
EXPORT = ["init","get_score","zoom_fit_all","scroll_home_y","print_dialog","edit_score_props","endmark_to_last","update_pending"];
