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
import("csound");
import("cairo");
import("math");
import("gtk");
import("winreg");
import("debug");
import("io");
import("palette");
import("progress");
import("unix");
import("single");
import("editor");
import("outbus");
import("playbus");
import("thread");
import("interval");
import("utils");

# have another way of admin the graphs,
# for example remove the graphs of the csound obj before
# setting the graph callback.
# perhaps put each graph in CsoundObj.graphs and (un)register
# each csound obj with the GraphWin?
# Then we could even abstract this to a graphwin that could be
# used for any graph plot, not just csound. merge with plot.nas
# grwin.register(object)

var draw_ftable = func(cr,wd,width,height,padding) {
    val2y = func(v,wd) {
        var h = height-padding*2;
        h-(((v-wd.min)/(wd.max-wd.min))*h);
    }
    cairo.translate(cr,padding,padding);
    palette.use_color(cr,"fg");
    for(var i=0; i<wd.npts; i+=1) {
        var x = i*((width-(padding*2))/wd.npts);
        cairo.line_to(cr,x,0.5+val2y(wd.fdata[i],wd));
    }
    cairo.set_line_width(cr,1);
    cairo.stroke(cr);
    palette.use_color_a(cr,"fg",0.5);
    cairo.move_to(cr,0,0.5+int(val2y(0,wd)));
    cairo.rel_line_to(cr,width,0);
    cairo.stroke(cr);
}

var GraphWin = {};
GraphWin.new = func {
    var o = {parents:[GraphWin]};
    o.graphs = {};
    o.selected = nil;
    o.height = 0;
    o.width = 0;
    o.padding = 2;
    o.w = gtk.Window("title","CSound graphs",
        "default-width",400,"default-height",200);
    o.w.connect("delete-event",func o.w.hide());
    o.d = gtk.DrawingArea();
    o.d.connect("expose-event",func(wid) o.expose(wid));
    o.d.connect("configure-event",func(wid,ev) {
        o.width = ev.width;
        o.height = ev.height;
    });

    var box2 = gtk.HBox();
    o.lbl = gtk.Label();
    o.l = gtk.ListStore_new("gchararray");
    o.b = gtk.ComboBox("model",o.l,"active",0);
    o.b.add_cell(gtk.CellRendererText(),1,"text",0);
    o.b.connect("changed",func(wid) {
        var r = num(wid.get("active"));
        if(r!=nil) {
            o.selected=o.l.get_row(r,0);
            o.upd_lbl();
        } else {
            o.selected=nil;
        }
        o.d.queue_draw();
    });
    box2.pack_start(o.b);
    box2.pack_start(o.lbl);
    var box = gtk.VBox();
    box.pack_start(box2,0);
    box.pack_start(o.d);
    o.w.add(box);
    return o;
}
GraphWin.upd_lbl = func {
    if(me.selected==nil) return;
    var wd = me.graphs[me.selected];
    me.lbl.set("label",
        sprintf("size: %d  min: %g  max: %g",wd.npts,wd.min,wd.max));
}
GraphWin.show = func {
    me.w.show_all();
    me.w.raise();
}
GraphWin.expose = func(wid) {
    if(me.selected==nil) return;
    var wd = me.graphs[me.selected];
    if(wd==nil) return;
    var cr = wid.cairo_create();
    palette.use_color(cr,"bg");
    cairo.paint(cr);
    draw_ftable(cr,wd,me.width,me.height,me.padding);
}
#import("debug");
GraphWin.add_graph = func(wd) {
    if(!contains(me.graphs,wd.caption))
        me.l.set_row(var r = me.l.append(),0,wd.caption);
    else
        var r = me.graphs[wd.caption].row;
    wd.row = r;
    me.graphs[wd.caption]=wd;
    me.b.set("active",wd.row);
    me.upd_lbl();
#    me.show();
    me.d.queue_draw();
}

var grwin = GraphWin.new();
winreg.add_window("Csound graphs",grwin.w,"<Alt>g");

#var draw_graph = func(wd) {
#    grwin.add_graph(wd);
#}

var extract_num = func(s) {
    var start = -1;
    var len = 0;
    for(var i=0;i<size(s);i+=1) {
        if(s[i]>=`0` and s[i]<=`9`) {
            if(start<0) start=i;
        } elsif(start>=0) {
            len = i-start;
            break;
        }
    }
    return substr(s,start,len);
}

var CSFtab = {name:"cs_ftab",parents:[single.ASSingle]};
CSFtab.description =
"<b>Single event CSound function table generator/visualizer.</b>\n\n"
"To be used with the csound objects <tt>ftable</tt> input.\n"
"The start time of this object is ignored.\n"
"<tt>parms</tt> is a vector of f-statement parameters,"
" like <tt>[1,0,1024,10,1]</tt> for a single sinewave cycle in ftab #1.\n\n"
"If set to a single element vector, it does not send any event "
"but only visualizes the specified function table.";
CSFtab.init = func(o) {
    single.ASSingle.init(o);
    o.parents=[CSFtab];
    o.height = 100;
    o.width = 200;
    o.parms = [];
    o.add_obj_prop("parms",nil,func {
        o.caption = "";
        foreach(var p;o.parms)
            o.caption ~= sprintf("%g",p) ~ " ";
        o.update();
    });
    o.add_obj_prop("width",nil,func {
        o.remake_surface();
    });
    o.new_outlet("out",0);
    o.wd = nil;
    o.can_draw_cs_ftab = 1;
}
CSFtab.update_geometry = func nil;
CSFtab.get_single = func {
    return me.parms;
}
CSFtab.draw = func(cr,ofs,width,last) {
    cairo.rectangle(cr,0.5,0.5,me.width-1,me.height-1);
#    cairo.set_dash(cr,[2,2]);
    cairo.stroke(cr);
#    cairo.set_dash(cr,0);
    if(me.wd==nil) return;
    draw_ftable(cr,me.wd,me.width,me.height,2);
    cairo.select_font_face(cr,"Mono");
    cairo.set_font_size(cr,9);
    cairo.move_to(cr,1,9);
    cairo.show_text(cr,sprintf("%+.2f",me.wd.max));
    cairo.move_to(cr,1,me.height-4);
    cairo.show_text(cr,sprintf("%+.2f",me.wd.min));

}
CSFtab.draw_cs_ftab = func(ftab,wd) {
    if(ftab==me.parms[0]) {
        me.wd=wd;
        me.redraw();
    }
}

var CSEvent = {name:"cs_instr",parents:[algoscore.ASObject]};
CSEvent.description =
"<b>Single CSound instrument event.</b>\n\n"
"p2 (time) and p3 (duration) is taken from "
"the position and length of the object.\n\n"
"<tt>instr</tt> property sets the instrument number.\n\n"
"<tt>parms</tt> property is a list of instrument parameters, starting with p4.\n"
"If <tt>in(X)</tt> is used instead of a numeric parameter in this list, an inlet"
" named X will be created and used to initialize that parameter.\n\n"
"Example: <tt>[100, in('A'), 1]</tt> will set p4 to 100, p5 to the current value"
" at the inlet A and p6 to 1.";
CSEvent.init = func(o) {
    algoscore.ASObject.init(o);
    o.parents = [CSEvent];
    o.height = 20;
    o.n_parms = 0;
    o.parms = [];
    o.parms_str = "[]";
    o.instr = 1;
    o.add_obj_prop("instr");
#    o.has_csound_connect_callback=1;
    
    var make_in = func(in) {
        in = sprintf("%s",in);
        if(!contains(o.inlets,in))
            o.new_inlet(in);
    }
    
    o.add_obj_prop("parms","parms_str",func {
        # backwards compatibility
        if(typeof(o.parms_str)=="vector")
            o.parms_str = debug.dump(o.parms_str);

        var ns = {in:make_in};
        var f = compile(o.parms_str);
        call(f,nil,o,ns);
            
        o.update();
    },1);
    o.new_outlet("out",0);
#    o.new_inlet("in");
}
CSEvent.get_datasize = func 1;
CSEvent.get_value = func(out,t) {
    return [me.instr,me.length]~me.parms;
}
CSEvent.get_event = func(out,t) {
    return [0,me.get_value(out,t)];
}
CSEvent.generate = func {
#    var in_get = me.inlets.in.val_finder(0);
    var in_get = func(in) me.inlets[sprintf("%s",in)].val_finder(0)(0);
    var ns = {in:in_get};
    var f = compile(me.parms_str);
    me.parms = call(f,nil,me,ns);
    0;
}
#CSEvent.csound_connect_callback = func(csobj,outlet,inlet) {
#    print("Connected to csound ",inlet,"\n");
    #get csobj.cs handle and use it to get event graphs?
#}
CSEvent.draw = func(cr,ofs,width,last) {
    var r = me.height/2;
    var r2 = me.height/3;
    cairo.translate(cr,0.5,0.5);
    cairo.set_line_width(cr,1);

    if(ofs==0) {
        cairo.new_path(cr);
        cairo.arc(cr,r,r,r-1,0,2*math.pi);
        cairo.stroke(cr);
    
        cairo.set_font_size(cr,r);
        cairo.select_font_face(cr,"Mono");
        var ext = cairo.text_extents(cr,me.instr);
        cairo.move_to(cr,r-ext.x_advance/2,r-ext.y_bearing/2);
        cairo.show_text(cr,me.instr);

        cairo.set_font_size(cr,8);
        cairo.move_to(cr,r*2+2,r-2);
        foreach(var p;me.parms) {
            cairo.show_text(cr,sprintf("%g",p));
            cairo.rel_move_to(cr,5,0);
        }
        cairo.move_to(cr,r*2,r);        
    } else
        cairo.move_to(cr,0,r);

    cairo.line_to(cr,width,r);
    
    if(last) {
        cairo.rel_move_to(cr,0,-r2);
        cairo.rel_line_to(cr,0,2*r2);
    }
    cairo.stroke(cr);
}

var CSEventG = {name:"cs_instr_graph",parents:[CSEvent]};
CSEventG.description = CSEvent.description ~
"\n\nThe <tt>graphs</tt> property is a hash like this:"
" <tt>{amp:{fill:1, lw:1, max:1}, foo:{fill:0, lw:2, max:100}}</tt>\n"
"The keys specifies what outvalue-channels to plot,"
" <tt>fill</tt> tells if the graph should be filled or not, <tt>lw</tt> is linewidth"
" and <tt>max</tt> the maximum value.\n\n"
"The values should be sent from the orchestra with code like this:\n"
"\n"
"  <tt>ktrig metro 50</tt>\n"
"  <tt>if ktrig == 1 then</tt>\n"
"    <tt>outvalue \"tag\", p1 ; needed to identify the event</tt>\n"
"    <tt>outvalue \"amp\", k1</tt>\n"
"    <tt>outvalue \"foo\", k2</tt>\n"
"  <tt>endif</tt>\n";
CSEventG.init = func(o) {
    CSEvent.init(o);
    o.parents = [CSEventG];
    o.has_cs_outval_callback=1;
    o.outvalues = nil;
    o.graphs = {
        amp:{fill:1,lw:1,max:1},
    };
    o.add_obj_prop("graphs");
}
CSEventG.cs_outval_callback = func(h) {
    var tag = me.event_tags[0];
#    print("tag = ",tag,"\n");
    me.outvalues = h[tag];
    me.redraw();
}
CSEventG.draw = func(cr,ofs,width,last) {
    me.caption = me.instr;
    foreach(var p;me.parms)
        me.caption ~= sprintf(" %g",p);

    var r = me.height/2;
    var r2 = me.height/3;
    cairo.translate(cr,0.5,0.5);
    cairo.set_line_width(cr,1);

    if(ofs==0) {
        cairo.move_to(cr,0,0);
        cairo.rel_line_to(cr,0,me.height);
    }
    cairo.move_to(cr,0,r);
    cairo.line_to(cr,width,r);
    if(last) {
        cairo.rel_move_to(cr,0,-r2);
        cairo.rel_line_to(cr,0,2*r2);
    }
    cairo.stroke(cr);
    
    if(me.outvalues!=nil) {
        foreach(var k;keys(me.graphs)) {
            var vals = me.outvalues[k];
            if(vals==nil) {
                print(me.get_label(),": no output values for '",k,"'\n");
                continue;
            }
            var g = me.graphs[k];
            var xr = size(vals)/me.width;
            cairo.move_to(cr,0,r);
            for(var i=0;i<width;i+=1) {
                var v = vals[int((ofs+i)*xr)];
                cairo.line_to(cr,i,r+(v*r/-g.max));
            }
            cairo.line_to(cr,width,r);
            if(g.fill) {
                palette.use_color(cr,"fill");
                cairo.fill_preserve(cr);
            }
            palette.use_color(cr,"fg");
            cairo.set_line_width(cr,g.lw);
            cairo.stroke(cr);
        }
    }
}

var CSBus = {name:"csound_bus",parents:[outbus.OutBus]};
CSBus.description =
"<b>CSound output bus.</b>\n\n"
"<tt>orc_file</tt> property sets the orchestra file to use.\n\n"
"<tt>events</tt> input takes instrument events as <tt>[p1,p3,...]</tt>"
" and gives them to csound with p2 set to the time of the"
" incomming event.\n\n"
"<tt>ftable</tt> input takes single events with GEN"
" parameters as <tt>[ftab_num, time, size, gen_num, gen_args...]</tt>\n\n"
"Any software channels defined in the orchestra will "
"show up in the connection list.";
CSBus.init = func(o) {
    outbus.OutBus.init(o);
    o.parents = [CSBus];
   
    o.cs = csound.create(o.id);
    o.orc_file = "";
    o.orc_file_found = nil;
    o.channels = [];
    o.orc_mtime = 0;
    o.graph_callbacks = [];
    o.graphs = [];
    o.outvalues = {};
    o.outfile = get_tmp_dir()~"/as"~unix.getpid()~"_csound"~o.id~".raw";
    o.port_id = "csnd"~o.id;
    o.bus = playbus.create_bus();
    o.amp = 1;
    
    o.add_obj_prop("amp",nil,func playbus.set_amp(o.bus,o.amp));
    o.add_obj_prop("orc_file",nil,func {
        o.caption = o.port_id~": "~o.orc_file;
        o.redraw();
    },1);

    o.new_inlet("events").keep=1;
    o.new_inlet("ftable").keep=1;

    o.thread_working = 0;
    o.thread_cancel = 0;
    o.thread_progress = 0;
    o.thread_lock = thread.newlock();
    o.thread_sem = thread.newsem();

#    gtk.timeout_add(250,func o.thread_monitor());
    o.thread_mon_id = interval.add_proc(func o.thread_monitor());

    o.register_bus();
    o.update_ports();
    
}
CSBus.update_ports = func {
    playbus.setup_ports(me.bus, me.port_id, csound.get_nchnls(me.cs));
}
CSBus.reconnect = func {
    playbus.remove_bus(me.bus);
    me.bus = playbus.create_bus();
    me.update_ports();
    me.update();
}
CSBus.update_channels = func {
    me.channels = csound.list_channels(me.cs);
    
    foreach(var k;keys(me.inlets))
        me.inlets[k].delete_me=1;

    foreach(var c;me.channels) {
        if(!c.input) continue;
        if(!contains(me.inlets,c.name))
            me.new_inlet(c.name);
        me.inlets[c.name].delete_me=0;
    }

    foreach(var k;keys(me.inlets)) {
        if(me.inlets[k].delete_me and me.inlets[k]["keep"]!=1)
            me.del_inlet(k);
    }
}
CSBus.query_inlets = func {
    if(me.orc_file_found==nil and !me.locate_orc_file()) return;
    var st = io.stat(me.orc_file_found);
    if(st==nil) return;
    if(st[9]>me.orc_mtime) {
        me.compile_csound(1);
        csound.reset(me.cs);
    }
}
CSBus.locate_orc_file = func {
    if(!size(me.orc_file)) return 0;
    me.orc_file_found = algoscore.locate_file(me.orc_file);
    if(me.orc_file_found==nil) {
        printerr(me.get_label(),": could not find orc file '",me.orc_file,"'\n");
        return 0;
    }
    return 1;
}
#CSBus.draw = func(cr,ofs,width,last) {
#    cairo.set_line_width(cr,2);
#    if(ofs==0) {
#        cairo.move_to(cr,1,0);
#        cairo.rel_line_to(cr,0,me.height);
#    }
#    cairo.move_to(cr,0,me.height/2);
#    cairo.rel_line_to(cr,width,0);
#    if(last) {
#        cairo.rel_move_to(cr,0,-me.height/2);
#        cairo.rel_line_to(cr,0,me.height);
#    }
#    cairo.stroke(cr);
#}
CSBus.do_graph_callbacks = func {
    foreach(var wd;me.graphs) {
        if(find("ftable",wd.caption)>=0) {
            var ftab = extract_num(wd.caption);
            foreach(var obj;me.graph_callbacks)
                obj.draw_cs_ftab(ftab,wd);
        }
    }
}
CSBus.compile_csound = func(no_sound=0) {
    if(!me.locate_orc_file()) return 0;
    var st = io.stat(me.orc_file_found);
    
    me.graphs = [];
# NOTE: this callback needs to be permanently referenced since the GC
# won't find it in the csound ghost!
    csound.set_graph_callback(me.cs,me.graph_callback=func(wd) append(me.graphs,wd));
    if(no_sound) var a = ["-n",me.orc_file_found];
    else var a = ["-+rtmidi=null","-+rtaudio=null","-m","6",
        "-f","-h","-o",me.outfile,me.orc_file_found];
    var err = csound.compile(me.cs,a);
    csound.dump_messages(me.cs);
    if(err) {
        printerr("CSound: terminated with error\n");
        return 0;
    }
#    This could be used for some fancy opcode browser GUI?
#    me.opcode_list = csound.list_opcodes(me.cs);
    
    me.update_ports();
    me.update_channels();
    me.orc_mtime = st[9];
    return 1;
}
CSBus.cleanup = func {
    unix.unlink(me.outfile);
    interval.remove_proc(me.thread_mon_id);
}
CSBus.edit_start = func {
    if(!me.locate_orc_file()) return 0;
    editor.open_file(me.orc_file_found);
    return 0;
}
CSBus.thread_monitor = func {
    thread.lock(me.thread_lock);
    
    if(me.thread_working!=0) {
        csound.dump_messages(me.cs);

        me.update_progress = me.thread_progress;

        if(me.thread_working==2) {
            print(me.get_label(),": update thread done\n");
            me.thread_working=0;
            me.pending_update = me.thread_cancel;
            if(me.thread_cancel) {
                thread.unlock(me.thread_lock);
                me.do_graph_callbacks();
                return 1;
            }

            thread.unlock(me.thread_lock);
            
            foreach(var wd;me.graphs)
                grwin.add_graph(wd);#,me.get_label()~":"~wd.caption);

            me.do_graph_callbacks();
            foreach(var o;me.outval_callbacks)
                o.cs_outval_callback(me.outvalues);
            me.score.queue_draw();                
            return 1;
        }
        
        me.score.queue_draw();
    }
    thread.unlock(me.thread_lock);
    return 1;
}
CSBus.cancel_generate = func {
    thread.lock(me.thread_lock);
    if(me.thread_working==1) {
        me.thread_cancel=1;
        thread.unlock(me.thread_lock);
        thread.semdown(me.thread_sem);
        return 1;
    }
    thread.unlock(me.thread_lock);
    return 0;
}
CSBus.generate = func {
#    if(me.cancel_generate())
#        print(me.get_label(),": restarting thread\n");
        
    if(!me.compile_csound()) return;

#    playbus.set_regions(me.bus,[[me.outfile,0,csound.get_nchnls(me.cs)]]);
    playbus.set_file(me.bus,[me.outfile,csound.get_nchnls(me.cs)]);
    if(playbus.get_sr()!=csound.get_sr(me.cs))
        printerr("Warning: Csound and JACK samplerate mismatch\n");

    # prepare events
    csound.rewind_score(me.cs);

    # send ftable events
    var ev_cons = me.inlets.ftable.get_connections();
    me.graph_callbacks = [];
    foreach(var con;ev_cons) {
        if(con.srcobj["can_draw_cs_ftab"]==1)
            append(me.graph_callbacks,con.srcobj);
        var ev = con.get_event(0);
        if(size(ev[1])>1)
            csound.score_event(me.cs,`f`,ev[1]);
    }

    # prepare for gathering of values from outvalue opcode
    me.outval_callbacks = [];
    csound.clear_outvalues(me.cs,me.outvalues={});

    # send instr events
    var ev_tag = 1;
    var ev_cons = me.inlets.events.get_connections();
    foreach(var con;ev_cons) {
        var taglist = [];
        for(var i=0;i<con.datasize;i+=1) {
            var ev = con.get_event(i);
            var t = ev[0];
            var inst = ev[1][0];
            # make unique p1 tags for each event
            inst = sprintf("%d.%05d",inst,ev_tag);
            append(taglist,ev_tag);
            ev_tag += 1;
            var ev2 = [num(inst),t]~subvec(ev[1],1);
            csound.score_event(me.cs,`i`,ev2);
        }
        # tell the event source obj what tags it got
        con.srcobj.event_tags = taglist;
        # does the source obj want the outvalue values?
        if(con.srcobj["has_cs_outval_callback"]==1)
            append(me.outval_callbacks,con.srcobj);
    }

    # make a list of k-rate input connections
    me.get_ch={};
    foreach(var c;me.channels) {
        if(!c.input) continue;
        var in = me.inlets[c.name];
        if(in.connected)
            me.get_ch[c.name]=in.val_finder(0);
    }

    # prepare update status variables
    thread.lock(me.thread_lock);
#    print_stderr("main clearing flags\n");
    me.thread_progress = 0;
    me.thread_working = 1;
    me.thread_cancel = 0;
    thread.unlock(me.thread_lock);
#    me.thread_sem = thread.newsem();
    
    # if this was not a restart, launch the thread monitor timer
#    if(!restart) gtk.timeout_add(200,func me.thread_monitor());

    # start the performance thread
#    print_stderr("main starting thread\n");
#    thread.newthread(func me.update_thread());
    thread.newthread(func {
        var err=[];
        call(me.update_thread,[],me,nil,err);
        if(size(err)) {
            printerr(utils.stacktrace(err));
            thread.semup(me.thread_sem);
        }
    });


    return 1;
}
CSBus.update_thread = func {
#    print_stderr("thread started\n");
    var t = 0;
    var length = me.score.endmark.time;
#    var kt = 1/csound.get_kr(me.cs);
    var do_semup = 0;
    while(t<length) {
#        print_stderr("thread locking\n");
        thread.lock(me.thread_lock);
#        print_stderr("thread locked\n");
        me.thread_progress = t;
        if(me.thread_cancel) {
            do_semup = 1;
            thread.unlock(me.thread_lock);
            break;
        }
        thread.unlock(me.thread_lock);
#        print_stderr("thread unlocked\n");

        # get g-rate input values
#        print_stderr("thread getting values\n");
        foreach(var k;keys(me.get_ch))
            csound.kchannel_write(me.cs,k,me.get_ch[k](t));
        # calculate one k-rate cycle of audio
#        print_stderr("thread performing ksmps\n");
        csound.perform_ksmps(me.cs);
#        print_stderr("thread getting score time\n");
        t = csound.get_score_time(me.cs);
#        t += kt;
    }

    csound.reset(me.cs);

#    thread.semup(me.thread_sem);
    
    thread.lock(me.thread_lock);
#    print_stderr("thread working = 2\n");
    me.thread_working = 2; #done
    thread.unlock(me.thread_lock);
    
    if(do_semup)
        thread.semup(me.thread_sem);
}

EXPORT=["CSBus","CSEvent","CSEventG","CSFtab"];
