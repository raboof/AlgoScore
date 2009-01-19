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

import("vec");
import("math");
import("unix");
import("io");
import("cairo");
import("debug");
import("utils");
import("options");
#import("gtk");

var usr_dir_index = nil;

#var ensure_dir = func(d) {
#    if(io.stat(d)==nil) {
#        var res = unix.mkdir(d);
#        if(res!=0) die("could not create dir: ",d);
#        else print("created dir: ",d,"\n");
#    }
#}

#options.add_option("user_data_dir",unix.getenv("HOME") ~ "/algoscore_data",func(d) {
options.add_option("user_data_dir","",func(d) {
    if(!size(d)) return;
    var usr_lib = d~"/lib";
    if(io.stat(usr_lib)==nil) return;
    if(usr_dir_index==nil) usr_dir_index = add_module_path(usr_lib);
    else add_module_path(usr_lib,usr_dir_index);
});

var core_class_dir = app_dir~"/classes";
add_module_path(core_class_dir);

#var curr_filename = nil;

var locate_file = func(f) {
    if(f==nil) return nil;
    if(f[0]==`/` and io.stat(f)!=nil) return f;
    var dirs = ["."];
#    if(curr_filename!=nil) append(dirs,dirname(curr_filename));
    var usr_dir = options.get("user_data_dir");
    var usr_lib = usr_dir~"/lib";
    if(usr_dir!="" and io.stat(usr_lib)!=nil) append(dirs,usr_lib);
    append(dirs,lib_dir);
    append(dirs,app_dir);
    foreach(var d;dirs) {
        var path = d ~ "/" ~ f;
        var st = io.stat(path);
        if(st!=nil) return path;
    }
    return nil;
}

#var set_curr_filename = func(f) curr_filename = f;

var classes = {};
#var register_class = func(c) {
#    print("registered class ",c.name,"\n");
#    classes[c.name] = c;
#}
var import_from_dir = func(cls_dir) {
    print("Importing classes from ",cls_dir,":\n");
    unix.chdir(cls_dir);
    var dir = unix.opendir(".");
    while(1) {
        var fn = unix.readdir(dir);
        if(fn==nil) break;
        if(io.filetype(fn)=="file") {
            var err = [];
            print("- ",fn,": ");
            call(run_file,[fn,var syms={}],nil,nil,err);
            if(size(err)) {
                print(utils.stacktrace(err,fn));
                continue;
            }
            var export = syms["EXPORT"];
            if(export!=nil) {
                foreach(var s;export) {
                    var c = syms[s];
                    if(typeof(c)=="hash") {
                        c.source_name = s;
                        c.class_file = fn;
                        c.class_dir = cls_dir;
                        if(c["name"]!=nil) {
                            print(c.name," ");
                            classes[c.name] = c;
                        }
                    }
                }
            }
            print("\n");
        }
    }
    unix.closedir(dir);
}
var import_classes = func {
    var cls_dirs = [core_class_dir];
    var usr_dir = options.get("user_data_dir");
    var usr_cls = usr_dir~"/classes";
#    if(size(usr_dir)) append(cls_dirs,usr_dir~"/classes");
    if(usr_dir!="" and io.stat(usr_cls)!=nil) append(cls_dirs,usr_cls);
    var old_dir = unix.getcwd();
    foreach(var d;cls_dirs)
        import_from_dir(d);
    unix.chdir(old_dir);
}
var get_classes = func classes;

var dump_descriptions = func(fn=nil) {
    import("regex");
    var in  = ['</?tt>','</?b>','</?i>','\n','-\s+(\S+)\s+:\s+'];
    var out = ['``','**','//',"@@\n",'| $1 | - '];
    forindex(i;in)
        in[i]=regex.new(in[i]);
    var convtags = func(s) {
        forindex(i;in)
            s=in[i].sub(s,out[i],1);
        return s;
    }
    
    if(fn==nil) fn=app_dir~"/src/doc/classes.inc";
    var f = io.open(fn,"w");
    io.write(f,"\n");
    var names=sort(keys(classes),cmp);
    foreach(var k;names) {
        var c = classes[k];
        if(c.class_dir!=core_class_dir) continue;
        io.write(f,"== "~c.name~" ==["~c.name~"_class]\n\n");
        io.write(f,convtags(c.description));
        io.write(f,"\n\n");
    }
    io.close(f);
}

var find_sym = func(o,s) {
    if(contains(o,s))
        return o[s];
    if(o["parents"]==nil) return nil;
    foreach(var p;o.parents)
        return find_sym(p,s);
}

#-------------------------------------------------------------------------
# Score

#:: == Score class ==[Score]
#:: The current score object is available as ``score`` in the console or
#:: ``me.score`` in classes.
#:: === Score.objects{} ===
#:: A table of all objects in the score, indexed by numerical ID.
var Score = {};
Score.init = func(o) {
    o.objects = {};
    o.last_id = 0;
    o.endmark = {type:"end",time:30};
    o.marks = [o.endmark];

    o.globals = {};
    o.global_supply = {};
    o.properties = {};
    o.metadata = {title:"",subtitle:"",composer:""};
    foreach(var m;keys(o.metadata)) {
        (func(sym) {
            o.properties[m] = {
                get:func o.metadata[sym],
                set:func(v) o.metadata[sym]=v,
                no_eval:1,
            }
        })(m);
    }
}

Score.new = func {
    var o = {parents:[Score]};
    me.init(o);
    o.queue_draw = func nil;
    o.zoom = 10; #pixels per second
    o.delay_update = 0;
    return o;
}

Score.sort_marks = func {
    me.marks = sort(me.marks,func(a,b) a.time>b.time);
}
Score.add_mark = func(type, time) {
    append(me.marks,{type:type,time:time});
    me.sort_marks();
}
Score.delete_mark = func(mark) {
    if(mark.type=="end") return;
    forindex(var n;me.marks) {
        if(me.marks[n]==mark) {
            me.marks = vec.delete(me.marks,n);
            return;
        }
    }
}
#Score.set_max_t_cb = func(f) me.max_t_cb = f;
#Score.update_max_t = func(obj) {
#    var t = obj.start + obj.length;
    # This is wrong!
    # just because it was the last object last time,
    # it doesn't mean it's still the last object...
    # if obj==last_obj and t<max_t, then we need
    # to search again!
#    if(obj==me.last_obj or t>me.max_t) {
#        me.max_t = t;
#        me.last_obj = obj;
#        me.max_t_cb();
#    }
#}

#:: === Score.new_obj_by_name(class_name) ===
#:: Create object from class ``class_name``.
Score.new_obj_by_name = func(name) {
    if(!contains(classes,name)) die("no such class: "~name~"\n");
    var obj = classes[name].new(me);
# since we call obj.update() in obj.move_done() from score_ui.nas after object creation,
# we don't need this here now, but later when move_done() only updates if there are
# connections, we need this here since a new object has no connections...
    obj.update(); #moved to score_ui.nas...
    print("Created ",obj.get_label(),"\n");
    return obj;
}
Score.register_object = func(obj,id=nil) {
    if(id==nil) {
        id = me.last_id;
        while(contains(me.objects,id)) id += 1;
    }
    obj.score = me;
    obj.id = id;
    me.objects[id] = obj;
    me.last_id = id;
#    me.update_max_t(obj);
    return id;
}
Score.unregister_object = func(obj) {
    delete(me.objects,obj.id);
#    if(me.last_obj==obj) {
#        me.last_obj=nil;
#        me.max_t=0;
#        foreach(var k;keys(me.objects)) {
#            var o = me.objects[k];
#            var t = o.start+o.length;
#            if(t > me.max_t) {
#                me.max_t = t;
#                me.last_obj = o;
#            }
#        }
#        me.max_t_cb();
#    }
}
Score.set_queue_draw = func(f) {
    me.queue_draw = f;
}

#:: === Score.time2x(t) ===
#:: Convert time in seconds to pixel position according to current zoom.
Score.time2x = func(t) t*me.zoom;
#:: === Score.x2time(x) ===
#:: Convert pixel position to time in seconds according to current zoom.
Score.x2time = func(x) x/me.zoom;

#:: === Score.update_all(all=0, list=nil, force=0) ===
#:: Update all objects.
#:: | ``all`` | - all objects if 1, otherwise only pending updates.
#:: | ``list`` | - list of objects if not nil, otherwise all objects.
#:: | ``force`` | - also objects with ``delay_update`` set.
Score.update_all = func(all=0,list=nil,force=0) {
#    if(me.delay_update and !all) return;

    var v = me.get_object_tree(list);
    
    foreach(var o;v) {
        #if(o.pending_update!=2) 
        o.cancel_generate();
    }
        
    foreach(var o;v) {
        if((!o.delay_update or force) and (all or o.pending_update)) {
            o.update_now();
        }
    }
}
# temporarily suspend auto-update, returns the old state
# which should be passed to unhold_update() to restore it.
Score.hold_update = func {
    var state = me.delay_update;
    me.delay_update = 1;
    return state;
}
Score.unhold_update = func(state,list=nil) {
    me.delay_update = state;

#    if(list!=nil) {
#        var obj_in_group_changed = 0;
#        foreach(var k;keys(list)) {
#            var o = list[k];
#            if(o.pending_update) {
#                obj_in_group_changed = 1;
#                break;
#            }
#        }
#        if(!obj_in_group_changed) return;
#    }

    if(!state) me.update_all(0,list);
}

#:: === Score.get_object_tree(list=nil) ===
#:: Get a list of all objects (or the ones in ``list``)
#:: sorted according to their dependencies.
Score.get_object_tree = func(list=nil) {
    var v = [];
    var tops = [];
    if(list==nil) {
        list=me.objects;
        foreach(var k;keys(list)) {
            var o = list[k];
            if(!o.has_parents())
                append(tops,o);
        }
    } else {
        var list_keys=keys(list);
        foreach(var k;list_keys) {
            var o = list[k];
            if(!o.has_parents_in(list_keys))
                append(tops,o);
        }
    }
    
    var visited = func(x) {
        foreach(var y;v) if(x==y) return 1;
        return 0;
    }
    var visit = func(obj) {
        foreach(var k;keys(obj.children)) {
            var o = obj.children[k];
            visit(o);
        }
        if(!visited(obj))
            append(v,obj);
    }
    foreach(var o;tops)
        visit(o);
        
    # reverse the list
    var v2 = setsize([],size(v));
    forindex(var i;v) v2[i] = v[-i-1];
    return v2;
}

#:: === Score.dump_objects() ===
#:: Generate a textual string that will create the current
#:: score with all objects if compiled and run as nasal code.
Score.dump_objects = func {
    var x = "";
    var v = me.get_object_tree();
    foreach(var o;v) {
        x ~= o.dump();
    }
        
    foreach(var k1;keys(me.objects)) {
        var o = me.objects[k1];
        foreach(var k;keys(o.links))
            x ~= "o"~o.id~".add_link(o"~k~","~o.links[k]~");\n";
    }
    
    x ~= "score.marks = "~debug.dump(me.marks)~";\n";
    
    x ~= "score.metadata = "~debug.dump(me.metadata)~";\n";
    
    return x;
}

#:: === Score.save_to_file(filename) ===
#:: Save the current score to file.
Score.save_to_file = func(fn) {
    unix.chdir(dirname(fn));
    var f = io.open(fn,"w");
    io.write(f,me.dump_objects());
    io.close(f);
    print("Saved score to file ",fn,"\n");
    me.queue_draw();
}
Score.destroy_all = func {
    foreach(var k;keys(me.objects)) {
        var o = me.objects[k];
        o.destroy(1);
    }
    me.objects = {};
}

#:: === Score.load_from_file(filename) ===
#:: Load a score from file.
Score.load_from_file = func(fn) {
    unix.chdir(dirname(fn));
    me.destroy_all();
    me.init(me);
#    var x = me.delay_update;
#    me.delay_update = 1;
    var x = me.hold_update();
    var ns = {
        score:me,
        finish:func(o) { #fixme: obsolete
#            o.update();
#            o.update_unused_regions();
            o.query_inlets(); 
        }
    };
    run_file(fn,ns);
    
    foreach(var m;me.marks)
        if(m.type=="end")
            me.endmark=m;
    
#    me.delay_update = x;
#    me.update_all();
    me.unhold_update(x);
    
#    print("objects: ",debug.dump(keys(me.objects)),"\n");
#    foreach(var k;keys(me.objects)) {
#        var o = me.objects[k];
#        print("Loaded ",o.get_label(),"\n");
#        if(!o.has_parents()) o.update();
#    }
}

#:: === Score.multi_copy(id, n, dt=nil, ghost=0) ===
#:: Make multiple copies of an object.
#:: | ``id`` | - the object ID.
#:: | ``n`` | - numer of copies.
#:: | ``dt`` | - amount of time each copy should be offset, defaults to objects length.
#:: | ``ghost`` | - if 1, create ghost copies instead of real copies.
Score.multi_copy = func(id,n,dt=nil,ghost=0) {
    var o = me.objects[id];
    var t = o.get_prop("start");
    var y = o.get_prop("ypos");
    if(dt==nil) dt=o.get_prop("length");
    for(var i=0;i<n;i+=1) {
        var o2 = o.duplicate(ghost);
        o2.set_prop("start",t+=dt);
        o2.set_prop("ypos",y);
    }
    me.queue_draw();
}
#:: === Score.align_ghosts() ===
#:: Vertically align all ghost copies with their parents.
Score.align_ghosts = func {
    foreach(var k;keys(me.objects)) {
        o=me.objects[k];
        if(o.is_ghost)
            o.set_prop("ypos",o.parents[0].ypos);
    }
}
#:: === Score.match_prop(prop, val) ===
#:: Return a list of IDs of all objects where property ``prop`` matches ``val``.
Score.match_prop = func(prop,val) {
    var v = [];
    foreach(var k;keys(me.objects)) {
        var o=me.objects[k];
        if(find_sym(o,prop)==val)
            append(v,k);
    }
    return v;
}
#:: === Score.many_set_prop(ids, prop, val) ===
#:: Set property on multiple objects at once.
#:: | ``ids`` | - a list of object IDs.
#:: | ``prop`` | - the name of the property.
#:: | ``val`` | - the value.
Score.many_set_prop = func(ids,prop,val) {
    foreach(var k;ids) {
        var o=me.objects[k];
        o.set_prop(prop,val);
    }
    return nil;
}

var new_gfx_cache = func {
    return {
        n:-1,
        redraw:0,
        surface:nil,
        visible:0,
    };
}

#:: == ASObject class ==[ASObject]
#:: This is the baseclass for all AlgoScore objects.
var ASObject = {source_name:"ASObject"};
ASObject.class_dir = lib_dir;
ASObject.class_file = "algoscore.nas";
ASObject.description = "(no description)";
ASObject.new = func(score) {
    var o = {};
    score.register_object(o);
    me.init(o);
    return o;
}
ASObject.init = func(o) {
    o.parents = [ASObject];
    o.inlets = {};
    o.outlets = {};
    o.con_cache = nil;
    o.start = 0; # position of object in seconds
    o.fixed_start = 0;
    o.length = 5; # length of object in seconds
#    o.surface = nil; # cairo surface
#    o.do_redraw_flag = 0;
    o.gfx_cache = [
        new_gfx_cache(),
        new_gfx_cache(),
    ];
    o.remake_surface_flag = 1;
    o.width = 10; # width in pixels
    o.height = 10; # height in pixels
    o.xpos = 0; # filled in by drawing function...
    o.ypos = 0; # vertical position

#:: === ASObject.children{} ===
#:: A table of objects that depends on this object. Used for
#:: dependency resolution when sorting the object tree.
    o.children = {}; # for dependency resolution
    o.links = {};
    o.alignments = [];
    o.timegrids = [];
    o.timegrid_pattern = 0;
    o.timegrids_enable = 0;
    o.timegrid_pos = 0;
    o.group = {};
    o.group[o.id] = o;
    o.properties = {};
    o.is_ghost = 0;
    o.caption = nil;
    o.caption_enable = 1;
    o.sticky = 0;
    o.pending_update = 0;
    o.delay_update = 0;
    o.update_progress = 0;

    o.add_obj_prop("height",nil,func o.remake_surface());
    o.add_obj_prop("length",nil,func o.resize_done());
    o.add_obj_prop("start",nil,func o.move_done());
    o.add_obj_prop("ypos",nil,func o.score.queue_draw());
    o.add_obj_prop("caption_enable",nil,func o.redraw());
    o.add_obj_prop("delay_update");
    
#    o.new_inlet("(depend)");
#    o.new_outlet("(depend)",0,0);
#    o.save_symbols = [
#        "start",
#        "length",
#        "ypos",
#    ];
}

#:: === ASObject.clean_globals(namespace=nil) ===
#:: Remove this object from the list of global suppliers.
#:: Additionally, if ``namespace`` is non-nil, add
#:: ``G_set(sym,val)`` and ``G_get(sym)`` to the namespace.
ASObject.clean_globals = func(ns=nil) {
    if(ns!=nil) {
        ns.G_set = func(s,v) me.set_global(s,v);
        ns.G_get = func(s) me.get_global(s);
    }
    var g = me.score.global_supply;
    foreach(var k;keys(g)) {
        delete(g[k].children,me.id);
        if(g[k]==me) delete(g,k);
    }
    return ns;
}
#:: === ASObject.set_global(sym, val) ===
#:: Set global variable ``sym`` to ``val`` and register
#:: this object as the supplier for that variable.
ASObject.set_global = func(sym,val) {
    me.score.global_supply[sym] = me;
    me.score.globals[sym] = val;
}
#:: === ASObject.get_global(sym) ===
#:: Get global variable ``sym`` and add this object
#:: as a children to the supplier of that variable.
ASObject.get_global = func(sym) {
    var src = me.score.global_supply[sym];
    if(src!=nil) src.children[me.id]=me;
    me.score.globals[sym];
}

#:: === ASObject.remake_surface() ===
#:: Recreate the current graphics cache for this object.
ASObject.remake_surface = func {
#print(me.get_label()," remake surface\n");
#    me.gfx_cache[0].surface = nil;
#    me.gfx_cache[1].surface = nil;
#    me.con_cache = nil;
    me.remake_surface_flag = 1;
    me.redraw();
}

#:: === ASObject.get_label() ===
#:: Return a label for this object, in the format classname[ID].
#:: Can be overridden by subclasses if wanted.
ASObject.get_label = func {
    me.name~"["~(me.is_ghost?"G":"")~me.id~"]";
}
#ASObject.dump_props = func {
#    x = "props:{";
#    foreach(var k;keys(me.properties)) {
#        var p = me.properties[k];
#        x ~= k~":";
#        var v = p.get();
#        x ~= p["no_eval"]!=1?debug.dump(v):v;
#        x ~= ",";
#    }
#    x ~= "}";
#    return x;
#}

#:: === ASObject.dump() ===
#:: Return a textual string that will create this object and all
#:: its properties if compiled and executed as nasal code.
ASObject.dump = func {
    var sym = "o"~me.id;
    
    if(me.is_ghost) {
        var x = sprintf("%s = o%d.duplicate(1);\n",
                    sym,me.parents[0].id);
    } else {
        var x = sym~" = score.new_obj_by_name(\""~me.name~"\");\n";
    }
    
    
    # score.new_obj_by_name() does obj.update()...
    foreach(var k;keys(me.properties)) {
        var p = me.properties[k];
        var v = debug.dump(p.get());
#        x ~= sym~".properties[\""~k~"\"].set("~v~");\n";
        x ~= sym~".set_prop(\""~k~"\", "~v~");\n";
    }
    
    if(me.is_ghost) return x;
#    foreach(var s;me.save_symbols)
#        x ~= sym~"."~s~"="~debug.dump(find_sym(me,s))~";\n";
#    x ~= "finish("~sym~");\n";
    
    var ins = keys(me.inlets);

    if(size(ins)) x ~= sym~".query_inlets();\n";
    
    foreach(var i;sort(ins,cmp)) {
        var inlet = me.inlets[i];
        foreach(var c;keys(inlet.connections)) {
            var con = inlet.connections[c];
            x ~= "c = "~sym~".connect(o"~con.srcobj.id~",\""
                ~con.outlet~"\",\""~i~"\","~con.draw_pos~");\n";
            foreach(var k;keys(con.properties)) {
                var p = con.properties[k];
                var v = debug.dump(p.get());
#                x ~= "c.properties[\""~k~"\"].set("~v~");\n";
                x ~= "c.set_prop(\""~k~"\", "~v~");\n";
            }
        }
    }
    return x;
}

#:: === ASObject.duplicate(ghost=0) ===
#:: Create a copy of this object with all its properties.
#:: If ``ghost`` is non-zero, create a ghost copy.
ASObject.duplicate = func(ghost=0) {
    if(ghost) {
        var o = {parents:[me],is_ghost:1};
#        me.score.register_object(o,'G'~me.id);
        me.score.register_object(o);
        # everything associated with other objects must be reset!
        o.group = {};
        o.group[o.id]=o;
        o.children = {};
        o.links = {};
        o.inlets = {};
        o.properties = {};
        o.generate = func 0;
        o.update = func nil;
        o.con_cache = nil;
        o.gfx_cache = [
            new_gfx_cache(),
            new_gfx_cache(),
        ];
        o.remake_surface();
        o.start = 0;
        o.ypos = 0;
        o.add_obj_prop("start",nil,func o.move_done());
        o.add_obj_prop("ypos",nil,func o.score.queue_draw());

#        foreach(var k;keys(me.inlets))
#            o.new_inlet(k);
        me.children[o.id]=o;
    } else {
        var o = me.score.new_obj_by_name(me.name);
        foreach(var k;keys(me.properties)) {
            var p = me.properties[k];
    #        var v = debug.dump(p.get());
            o.properties[k].set(p.get());
        }
#        foreach(var s;me.save_symbols) {
#            o[s] = find_sym(me,s);
#        }
#        o.move_done();
    }
    return o;
}

#:: === ASObject.edit_event(ev) ===
#:: Override this to handle key and mouse events in //edit mode//.
#:: ``ev`` is a standard GTK event.
ASObject.edit_event = func nil;
#:: === ASObject.edit_start() ===
#:: Called when the user requests //edit mode// on this object.
#:: Return 1 to stay in edit mode (events will be sent to me.edit_event())
#:: or 0 to exit edit mode.
ASObject.edit_start = func 0;
#:: === ASObject.edit_end() ===
#:: Called when the user exits //edit mode// on this object.
ASObject.edit_end = func nil;

#:: === ASObject.add_obj_prop(name, sym=nil, cb=nil, no_eval=0) ===
#:: Add an object property.
#:: | ``name`` | - the name of the property as shown in the GUI.
#:: | ``sym`` | - the symbol of the property as stored in the object. Defaults to ``name``.
#:: | ``cb`` | - the callback to be called when this property changed.
#:: | ``no_eval`` | - if 0, evaluate the property as nasal code, else treat it as a string.
ASObject.add_obj_prop = func(name,sym=nil,cb=nil,no_eval=0) {
    var obj = me;
    if(sym==nil) sym=name;
    me.properties[name] = {
        get:func obj[sym],
        set:func(v) {
            obj[sym]=v;
            if(cb!=nil) cb(name,sym,v);
            else obj.update();
        },
        no_eval:no_eval,
    }
}

# deprecate this?
ASObject.add_out_prop = func(outlet,name,cb=nil) {
    var obj = me;
    me.properties[outlet~"."~name] = {
        get:func obj.outlets[outlet][name],
        set:func(v) {
            obj.outlets[outlet][name]=v;
            if(cb!=nil) cb(name,outlet,v);
            else obj.update();
        }
    }
}
ASObject.del_out_prop = func(outlet,name) delete(me.properties,outlet~"."~name);

#:: === ASObject.del_obj_prop(name) ===
#:: Delete an object property.
ASObject.del_obj_prop = func(name) delete(me.properties,name);

#:: === ASObject.set_prop(name, val) ===
#:: Set an object property.
ASObject.set_prop = func(name,val) {
    if(!contains(me.properties,name))
        printerr("Warning: ",me.get_label(),": no such property: '",name,"'\n");
    else
        me.properties[name].set(val);
}
#:: === ASObject.get_prop(name) ===
#:: Get an object property.
ASObject.get_prop = func(name) {
    if(!contains(me.properties,name))
        printerr("Warning: ",me.get_label(),": no such property: '",name,"'\n");
    else
        me.properties[name].get();
}

#:: === ASObject.new_inlet(name) ===
#:: Create new inlet.
ASObject.new_inlet = func(name) {
    me.inlets[name] = Inlet.new(me);
}
#:: === ASObject.del_inlet(name) ===
#:: Disconnect and remove inlet.
ASObject.del_inlet = func(name) {
    var in = me.inlets[name];
    if(in==nil) return;
    in.disconnect_all();
    delete(me.inlets,name);
}
#:: === ASObject.delete_all_inlets() ===
#:: Delete all inlets.
ASObject.delete_all_inlets = func {
    me.disconnect_all();
    me.inlets={};
}

#:: === ASObject.disconnect_all() ===
#:: Disconnect all inlets.
ASObject.disconnect_all = func {
    foreach(var k;keys(me.inlets))
        me.inlets[k].disconnect_all();
}

#:: === ASObject.new_outlet(name, res=0, ipol=0) ===
#:: Add a new outlet.
#:: | ``name`` | - the name of the outlet.
#:: | ``res`` | - sample resolution in seconds or 0 for event data.
#:: | ``ipol`` | - 1 to interpolate between events or samples.
ASObject.new_outlet = func(name,res=0,ipol=0) {
    return me.outlets[name] = {
        data:[],
        resolution:res,
        interpolate:ipol,
        audiobuf:nil,
    };
}

#:: === ASObject.cleanup() ===
#:: Override this to define a handler for cleaning up
#:: when this object is destroyed.

#:: === ASObject.destroy(all=0) ===
#:: Destroy this object and call all cleanup handlers in the
#:: class parents. If ``all`` is zero, unregister it from the
#:: score and remove all connections, etc...
ASObject.destroy = func(all=0) {
    var _clean = func(o) {
        var f = o["cleanup"];
        if(f!=nil) call(f,nil,me);
        if(!contains(o,"parents")) return;
        foreach(var p;o.parents) {
            _clean(p);
        }
    }
    _clean(me);

    if(!all) {
        var old = me.score.hold_update();

        foreach(var id; keys(me.children)) {
            var dest = me.children[id];
            foreach(var inlet;keys(dest.inlets)) {
#                print("destroy() calling disconnect() for inlet ",inlet,"\n");
                dest.disconnect(me,inlet);
            }
        }
        me.disconnect_all();
        me.remove_all_links();
        if(me.is_ghost) delete(me.parents[0].children,me.id);
        me.score.unregister_object(me);
        
        me.score.unhold_update(old);
    }
}

#:: === ASObject.get_parents() ===
#:: Return a table of all objects connected to this object.
ASObject.get_parents = func {
    var parents = {};
    foreach(var k; keys(me.inlets)) {
        var inlet = me.inlets[k];
        foreach(var k2; keys(inlet.connections)) {
            var con = inlet.connections[k2];
#            if(con.srcobj!=me) 
            parents[k2] = con.srcobj;
        }
    }
    return parents;
}

#:: === ASObject.has_parents() ===
#:: Return 1 if any objects are connected to this object.
ASObject.has_parents = func() {
    foreach(var k; keys(me.inlets))
        if(size(me.inlets[k].connections)>0) return 1;
    return 0;
}
#:: === ASObject.has_parents_in(list) ===
#:: Return 1 if any objects in ``list`` are connected to this object.
ASObject.has_parents_in = func(list) {
    foreach(var k; keys(me.inlets)) {
        foreach(var c;keys(me.inlets[k].connections)) {
            if(contains(list,c)) return 1;
        }
    }
    return 0;
}

ASObject._upd_unused_regions = func {
    var used_regions = [];
    var meB = me.start+me.length;
    foreach(var k; keys(me.children)) {
        var o = me.children[k];
        var A = math.max(me.start,o.start);
        var B = math.min(meB,o.start+o.length);
        if(B>A) append(used_regions,[A,B]);
    }
    append(used_regions,[meB,0]);
    var v = [];
    used_regions = sort(used_regions,func(a,b) a[0] > b[0]);
    var last = me.start;
    foreach(var r; used_regions) {
        var rA = last;
        var rB = r[0];
        last = r[1];
        if(rB>rA) append(v, [rA,rB-rA]);
    }
    me.unused_regions = v;
}
ASObject.update_unused_regions = func {
    if(size(me.outlets)==0) {
        me.unused_regions = [];
        return;
    }
    var parents = me.get_parents();
    foreach(var k; keys(parents)) {
        parents[k]._upd_unused_regions();
    }
    me._upd_unused_regions();
}
ASObject.find_con_space = func(src) {
    var v = [];
    var x1 = math.max(me.xpos,src.xpos);
    var x2 = math.min(me.xpos+me.width,src.xpos+src.width);
    var minmax = func(a,b) a<b?[a,b]:[b,a];
    
    var vert_outside = func(o1,o2) {
        var m1 = minmax(o1.ypos,o2.ypos);
        var m2 = minmax(me.ypos,src.ypos);
        if(m1[1] <= m2[0] or m1[0] >= m2[1]) return 1;
        else return 0;
    }
    
    foreach(var ok;keys(me.score.objects)) {
        var obj = me.score.objects[ok];
#       FIXME: only if(obj overlaps...
        foreach(var in;keys(obj.inlets)) {
            var inlet = obj.inlets[in];
            foreach(var ck;keys(inlet.connections)) {
                var con = inlet.connections[ck];
#                var x = me.score.time2x(con.draw_pos);
                var x = me.score.time2x(obj.start+con.draw_pos);
                if(x >= x1 and x <= x2 and !vert_outside(obj,con.srcobj))
                    append(v,x);
            }
        }
    }
    append(v,x2);
    var space_w = 0;
    var space_x = 0;
    var last_x = x1;
    foreach(var x; v) {
        var s = x-last_x;
        if(s>space_w) {
            space_w = s;
            space_x = last_x;
        }
        last_x = x;
    }
#    return me.score.x2time(space_x+space_w/2);
    return me.score.x2time(space_x+space_w/2)-me.start;
}

#:: === ASObject.xy_inside(x,y) ===
#:: Return true if x,y is inside the active "click region" of object.
#:: Can be overridden by subclasses.
ASObject.xy_inside = func(x,y) {
    return (x >= me.xpos and x <= me.xpos+me.width
        and y >= me.ypos and y <= me.ypos+me.height)
        ? 1 : 0;
}
ASObject.get_con_top_ypos = func(x) {
    return me.ypos;
}
ASObject.get_con_bottom_ypos = func(x) {
    return me.ypos+me.height;
}

#:: === ASObject.connect(src, outlet, inlet, pos=nil) ===
#:: Connect ``outlet`` of object ``src`` to ``inlet`` on this object.
#:: If ``pos`` is given, set connections graphical position.
#:: Returns the created [Connection #Connection] object or nil if failed.
ASObject.connect = func(src,outlet,inlet,pos=nil) {
    if(!contains(me.inlets,inlet)) {
#        print(me.id,me.name,": No such inlet: ",inlet,"\n");
#        return nil;
        me.new_inlet(inlet);
    }
    if(src==me) {
        printerr(me.get_label(),": Can't connect to myself\n");
        return nil;
    }
    
    var chk_cycle = func(o) {
        if(o==src) return 1;
        foreach(var k;keys(o.children)) {
            var o2 = o.children[k];
            if(chk_cycle(o2)) return 1;
        }
        return 0;
    }
    
    if(chk_cycle(me)) {
        printerr(me.get_label(),": Warning, cyclic connections\n");
#        return 0;
    }
    if(pos==nil) {
        var q = me.inlets[inlet].connections[src.id];
        if(q!=nil) { # we are replacing existing connection
            if(q.outlet==outlet) return q;
            var pos = q.draw_pos;
        } else {
            var pos = me.find_con_space(src);
        }
    }
    var con = me.inlets[inlet].connect(src,outlet,pos);
    src.update_unused_regions();
    me.con_cache=nil;
    me.update();
    me.connect_done(src,outlet,inlet);
    return con;
}
#:: === ASObject.connect_done(src, outlet, inlet) ===
#:: Override this to be called when connection is done.
ASObject.connect_done = func nil;

#:: === ASObject.disconnect(src, inlet, do_update=1) ===
#:: Disconnect object ``src``from ``inlet`` on this object.
#:: If ``do_update`` is zero, don't update this object.
ASObject.disconnect = func(src,inlet,do_update=1) {
    if(me.inlets[inlet].disconnect(src)) {
        me.con_cache=nil;
        src.update_unused_regions();
        if(do_update) me.update();
    }
}
#:: === ASObject.query_inlets() ===
#:: Override this to be called before user gets the list of available
#:: inlets.
ASObject.query_inlets = func nil;

ASObject.get_connected_inlets = func(src) {
    var v = [];
#    me.query_inlets();
    foreach(var k;keys(me.inlets)) {
        var inlet = me.inlets[k];
        if(contains(inlet.connections,src.id)) append(v,k);
    }
    return sort(v,cmp);
}
ASObject.get_unconnected_inlets = func(src,outlet) {
    var v = [];
    me.query_inlets();
    foreach(var k;keys(me.inlets)) {
#        if(k=="(depend)") continue;
        var con = me.inlets[k].connections[src.id];
#        if(con==nil or (con!=nil and con.outlet!=outlet)) append(v,k);
#        elsif(dot_connected) append(v,"."~k);
        if(con!=nil and con.outlet==outlet) append(v,"."~k);
        elsif(con==nil) append(v,k);
        else append(v,","~k);
    }
    return sort(v,cmp);
}
ASObject.add_group = func(src) {
    var g = me.group;
    var g2 = src.group;

    foreach(var k;keys(g2))
        g[k] = g2[k];
        
    g[me.id] = me;
    g[src.id] = src;
    
    foreach(var k;keys(g)) {
        var o = g[k];
        o.group = g;
    }
}

# Isaks update_group_id(): untested...
#      ngrp = 0
#      def f(node):
#        if node.grp:
#          return grp
#        for c in node.children:
#          grp = f(c)
#        if not grp:
#          ngrp += 1
#          grp = ngrp
#        node.grp = grp
#        return grp
#     
#      for n in nodes:
#        if not n.grp:
#          f(n)

ASObject.rebuild_groups = func {
    var g = me.group;

    foreach(var k;keys(g)) {
        #let each group of all objects in our group
        #contain only theirself.
        g[k].group = {};
        g[k].group[k]=g[k];
    }

    foreach(var k;keys(g)) {
        var o1 = g[k];
        foreach(var l;keys(o1.links)) {
            var o2 = g[l];
            o1.add_group(o2);
        }
    }
}

#:: === ASObject.add_link(src, t) ===
#:: Add link from object ``src`` to this object,
#:: at position ``t`` in seconds.
ASObject.add_link = func(src,t) {
    if(src==me) return 0; # can't link to itself
    if(src.links[me.id]!=nil) delete(src.links,me.id);
    me.links[src.id] = t;
    me.add_group(src);
    return 1;
}
#:: === ASObject.is_linked(src) ===
#:: Return 1 if this object is linked with ``src``.
ASObject.is_linked = func(src) me.links[src.id]!=nil or src.links[me.id]!=nil;
#:: === ASObject.remove_link(src) ===
#:: Remove any link between this object and ``src``.
ASObject.remove_link = func(src) {
    if(!me.is_linked(src)) return;
    delete(me.links,src.id);
    delete(src.links,me.id);
    me.rebuild_groups();
}
#:: === ASObject.remove_all_links() ===
#:: Remove all links between this object and any other object.
ASObject.remove_all_links = func {
    me.links={};
    foreach(var k;keys(me.group)) {
        var o = me.group[k];
        delete(o.links,me.id);
    }
    me.rebuild_groups();
}
ASObject.get_link_max_t = func {
    var m = 0;
    foreach(var k;keys(me.group)) {
        var o = me.group[k];
        foreach(var k2;keys(o.links)) {
            var t = o.links[k2] + (o.start-me.start);
            if((o==me or o.links[me.id]!=nil) and t>m) m=t;
        }
    }
    return m;
}

#:: === ASObject.get_alignments() ===
#:: Return a list of alignment points (in seconds)
#:: of this object. Defaults to a sorted ``me.alignments``
#:: with 0 and ``me.length`` added.
ASObject.get_alignments = func {
    var v = sort(me.alignments,func(a,b) a>b);
    if(size(v)==0 or v[0] != 0) v = [0] ~ v;
    if(v[-1] != me.length) v ~= [me.length];
    return v;
}
#:: === ASObject.get_object_tree() ===
#:: Returns the topological sort of the dependency tree with this
#:: object as the root object.
ASObject.get_object_tree = func {
    var v = [];
    var visited = func(x) {
        foreach(var y;v) if(x==y) return 1;
        return 0;
    }
    var visit = func(obj) {
        foreach(var k;keys(obj.children)) {
            var o = obj.children[k];
            if(o!=me) visit(o);
#            else print(me.id,me.name,": cyclic dependency!\n");
        }
        if(!visited(obj))
            append(v,obj);
    }
    visit(me);
    # reverse the list
    var v2 = setsize([],size(v));
    forindex(var i;v) v2[i] = v[-i-1];
    return v2;
}

#:: === ASObject.update_now() ===
#:: Force update of this object now.
ASObject.update_now = func {
#print(me.get_label(),": update()\n");
    me.update_progress = 0;
#    me.pending_update = me.generate();
    me.pending_update = call(me.generate,nil,me,nil,var err=[]);
    if(size(err)) {
        printerr(utils.stacktrace(err));
        me.pending_update = 1;
        return 1;
    }
    me.redraw();
#    me.pending_update=0;
    return 0;
}

#:: === ASObject.generate() ===
#:: The subclass-provided function that generates the data for this object,
#:: called when this object is updated.
#:: Should return 0 if finished, or 1 if not. Most classes should return 0,
#:: returning 1 is for the case of output busses at the end of the connection
#:: graph, which might render in a background thread. They should then set
#:: obj.pending_update to 0 when the thread finishes.
ASObject.generate = func 0;

#:: === ASObject.cancel_generate() ===
#:: Output busses that render in background threads can define this to
#:: be called when the user asks to cancel the processing.
ASObject.cancel_generate = func 0;

#:: === ASObject.update(children_only=0) ===
#:: Update object.
#:: Call this whenever the object and all its children should generate
#:: it's data. For example after user-editing some property or data of the object.
#:: 
#:: ``children_only``:
#:: | 0 | - for this obj and it's children,
#:: | 1 | - for children only,
#:: | -1 | - for this obj only, but set pending update for children.
ASObject.update = func(children_only=0) {
    var v = me.get_object_tree();
    
    foreach(var o;v)
        o.cancel_generate();
        
    foreach(var o;v) {
#        print(o.get_label(),": delay_update: ",o.delay_update,"\n");
        if(children_only<=0 or o!=me) {
            if((o.delay_update or me.score.delay_update) and (children_only>=0 or o!=me)) {
#                print(o.get_label()," queueing update\n");
                o.pending_update = 1;
                o.update_progress = 0;
            } else {
#                print(o.get_label()," update now\n");
                if(o.update_now()) return 0;
            }
        }
    }
    return 1;
}

#:: === ASObject.update_if_connected() ===
#:: Update this object if it is connected to any other object.
ASObject.update_if_connected = func {
    if(me.has_parents()) return me.update();
#    if(size(me.get_parents())) return me.update();
    if(size(me.children)) return me.update(1);
    return 0;
}
#:: === ASObject.redraw() ===
#:: Sets ``redraw`` flag to indicate that this object needs redrawing.
#:: Call this whenever the object should redraw.
#:: The flag is checked by Score.redraw() 
ASObject.redraw = func {
    #print(me.get_label()," redraw\n");
#    me.do_redraw_flag = 1;
    me.gfx_cache[0].redraw=1;
    me.gfx_cache[1].redraw=1;
    me.score.queue_draw();
}

#:: === ASObject.move_resize_done(moved, resized) ===
#:: Called after object has been moved (start or ypos changed)
#:: and/or resized (length changed). Could be overridden by subclass.
ASObject.move_resize_done = func(moved=1, resized=1) {
    if(resized) {
        if(me.length<0)
            me.length=1;
#        me.surface = nil;
        me.remake_surface();
        me.update();
    } elsif(moved) {
        me.update_if_connected();    
    }
#    me.score.update_max_t(me);
    me.update_unused_regions();
}
ASObject.move_done = func me.move_resize_done(1,0);
ASObject.resize_done = func me.move_resize_done(0,1);

#:: === ASObject.draw(cr, ofs, width, last) ===
#:: The subclass-provided function that draws the object.
#:: | ``cr`` | - cairo context to draw on.
#:: | ``ofs`` | - offset into the total object width that this sub-surface starts on. That is, the x pixel that 0 corresponds to. Zero when drawing on the first sub-surface.
#:: | ``width`` | - width of the sub-surface, clipped to the total object width in the last sub-surface, where ``last`` is 1 instead of 0.
ASObject.draw = func(cr,ofs,width,last) { nil; }

#:: === ASObject.update_geometry(cr, canvas_width) ===
#:: The subclass-provided function that updates obj.width.
#:: Default is based exactly on obj.length.
ASObject.update_geometry = func(cr,canvas_width) {
    me.width = int(me.score.time2x(me.length));
}

#:: === ASObject.interpolate(outlet, a, b, x) ===
#:: Function to interpolate between a and b, where x is between 0.0 and 1.0
#:: can be overridden by subclass.
# ...should perhaps be moved to Plot subclass?
# and perhaps put in each outlet instead? (then rename this to default_interpolate)
ASObject.interpolate = func(outlet, a, b, x) {a+x*(b-a);}

#:: === ASObject.default_get_value(outlet, t) ===
#:: Get value at time ``t`` on ``outlet``, reading ``outlet.data``
#:: as samples if ``outlet.resolution`` is non-zero or events if zero,
#:: interpolating with ``me.interpolate()`` if ``outlet.interpolate`` is non-zero.
ASObject.default_get_value = func(outlet, time) {
#    var myres = me.get_resolution(outlet);
    var myres = me.outlets[outlet].resolution;
    var data = me.outlets[outlet].data;
    if(time<0) time=0;
    elsif(time>me.length) time=me.length;
    var do_line = me.outlets[outlet].interpolate;    

    if(myres > 0) {
        # sample data
        var i = time/myres;
        if(i>=size(data))
            return data[-1];
        else
            return do_line?vec.ipol(data,i):data[i];
            #FIXME: vec.ipol interpolates back to first value after last,
            #we should just stay at the last value..
    } else {
        # event data
        var t = data[0][0];
        var val = data[0][1];
        for(var i=0; i<size(data); i+=1) {
            var dt = data[i][0]-t;
            var t = data[i][0];
#            var dt = data[i][0];
#            t += dt;
            if(t>time) {
                if(do_line) {
                    var x = (dt-(t-time))/dt;
                    return me.interpolate(outlet,val,data[i][1],x);
                } else {
                    return val;
                }
            }
            var val = data[i][1];
        }
        return val;
    }
}

#        var do_line = me.get_interpolating(outlet);
#        var t = 0;
#        for(var i=0; i<size(data); i+=1) {
#            var len = data[i][0];
#            var val = data[i][1];
#            t += len;
#            if(t>time) {
#                if(do_line and i+1<size(data)) {
#                    var x = (len-(t-time))/len;
#                    return me.interpolate(val,data[i+1][1],x);
#                } else {
#                    return val;
#                }
#            }
#        }
#        return val;
#    }

#:: === ASObject.get_value(outlet, t) ===
#:: Get value at time ``t`` on ``outlet``.
#:: Can be overridden by subclass, default calls ``me.default_get_value()``.
#:: Note that this might be called from an output bus background thread, and
#:: must be thread safe.
#ASObject.get_value = func(o,t) me.default_get_value(o,t);
ASObject.get_value = ASObject.default_get_value;

#:: === ASObject.default_get_event(outlet, index) ===
#:: Get event number ``index`` on ``outlet``,
#:: in the format ``[t, value]``.
#:: Can be overriden by subclass.
ASObject.default_get_event = func(outlet, index) {
#    var myres = me.get_resolution(outlet);
    var myres = me.outlets[outlet].resolution;
    var data = me.outlets[outlet].data;

    if(index < 0) index=0;
    elsif(index >= size(data)) index=size(data)-1;
    
    if(myres > 0)
        return [index*myres,data[index]];
    else
        return data[index];
}

#:: === ASObject.get_event(outlet, i) ===
#:: Get event at index ``i`` on ``outlet``.
#:: Can be overridden by subclass, default calls ``me.default_get_event()``.
#:: Note that this might be called from an output bus background thread, and
#:: must be thread safe.
ASObject.get_event = ASObject.default_get_event;

#:: === ASObject.get_datasize(outlet) ===
#:: Get number of elements in ``outlet.data``, either number of
#:: events or number of samples.
#:: Can be overriden by subclass.
ASObject.get_datasize = func(outlet) {
    return size(me.outlets[outlet].data);
}

# functions to return the data, can be overridden by subclass.
# outlet is the name of the outlet
# length is the length in seconds
# res is the optional resolution in seconds
ASObject.old_get_samples = func(outlet,length,res=nil) {
    var myres = me.get_resolution(outlet);
    var data = me.outlets[outlet].data;
    if(myres > 0) {
        # sample data
        if(res == nil) res = myres;
        var in = subvec(data, 0, length / myres);
        var sz2 = int(length / res);
        return vec.resample(in, sz2, 1);
    } else {
        # event data
        if(res == nil) die("get_samples: resolution must be given for outlet "~outlet);
        var sz2 = int(length / res);
        var v = setsize([], sz2);
        var i2 = var i3 = var val1 = 0;
        var do_line = me.get_interpolating(outlet);
        for(var i = 0; i < size(data); i += 1) {
            i3 += int(data[i][0] / res);
            var val2 = data[i][1];
            for(var j = i2; j < i3; j += 1) {
                if(do_line) {
                    var x = ((j - i2) / (i3 - i2));
                    v[j] = me.interpolate(val1, val2, x);
                } else {
                    v[j] = val1;
                }
            }
            i2 = i3;
            val1 = val2;
        }
        for(; i2 < sz2; i2 += 1)
            v[i2] = val1;
        return v;
    }
}
ASObject.old_get_events = func(outlet,length) {
    var myres = me.get_resolution(outlet);
    var data = me.outlets[outlet].data;
    if(!myres) {
        # event data
        var t = 0;
        for(var i=0; i<size(data); i+=1) {
            t += data[i][0];
            if(t>=length) break;
        }
        return subvec(data,0,i);
    } else {
        # sample data
        var v=[];
        var sz2 = int(length/myres);
        var val = data[0];
        var t = 0;
        append(v,[t,val]);
        for(var i=1; i<sz2 and i<size(data); i+=1) {
            t += myres;
            if(data[i]!=val) {
                val = data[i];
                append(v,[t,val]);
                t = 0;
            }
        }
        return v;
    }
}

#:: == Inlet class ==[Inlet]
#:: An Inlet object is a named input slot of an object, and holds any number
#:: of [connection #Connection] objects.
var Inlet = {};
Inlet.new = func(obj) {
    var o = {parents:[Inlet]};
    o.connections = {};
    o.destobj = obj;
    o.datasize = 0;
    o.connected = 0;
    o.con_props = {};

    o.add_con_prop("transfer func","transfunc_str",
        {transfunc_str:"",transfunc:nil},
        func(con) {
        if(size(con.transfunc_str)) {
            var err = [];
            var compfn = func compile(con.transfunc_str, "transfer func");
            var code = call(compfn, nil, nil, nil, err);
            if(size(err))
                printerr(utils.stacktrace(err));
            else
                con.transfunc = code;
        } else
            con.transfunc = nil;
#        con.srcobj.update();
        o.destobj.update();
    },1);
    
    o.add_con_prop("hide_inlet",nil,{hide_inlet:0},func(con) {
        o.destobj.score.queue_draw();
    });

    return o;
}

#:: === Inlet.add_con_prop(name, sym=nil, init=nil, cb=nil, no_eval=1) ===
#:: Add a property for connections to this inlet.
#:: Arguments is similar to [ASObject #ASObject].add_obj_prop().
#:: ``init`` is a table of symbols and their initialization values.
Inlet.add_con_prop = func(name,sym=nil,init=nil,cb=nil,no_eval=1) {
    me.con_props[name]=[sym,cb,init,no_eval];
}
Inlet.connect = func(src,outlet,pos=nil) {
    var con = Connection.new(src,outlet);
    me.connections[src.id] = con;
    src.children[me.destobj.id] = me.destobj;
    if(pos!=nil) con.draw_pos=pos;
    me.connected=size(me.connections);
 
    foreach(var k;keys(me.con_props)) {
        var p = me.con_props[k];
        if(p[2]!=nil) {
            foreach(var k2;keys(p[2]))
                con[k2]=p[2][k2];
        }
        con.add_prop(k,p[0],p[1],p[3]);
    }
    
    return con;
}
Inlet.disconnect_all = func {
    foreach(var k;keys(me.connections)) {
        var src = me.connections[k].srcobj;
        me.disconnect(src);
        src.update_unused_regions();
    }
}
Inlet.disconnect = func(src) {
    if(!contains(me.connections,src.id)) return 0;
    delete(me.connections,src.id);
    #if it was the last connection from src to dest, delete from src.children
    var v = me.destobj.get_connected_inlets(src);
    if(size(v)==0) delete(src.children,me.destobj.id);
    me.connected=size(me.connections);
    return 1;
}
Inlet.distance = func(con) { #?
    var d = con.srcobj.ypos - me.destobj.ypos;
    if(d<0) d = -d;
    return d;
}
#Inlet.is_connected = func size(me.connections)>0;

#:: === Inlet.get_connections() ===
#:: Returns a list of all Connection objects for this inlet.
#:: Also sets ``inlet.datasize`` as the sum of each connections datasize,
#:: and ``connection.datasize`` which is retreived through ``source_obj.get_datasize(outlet).``
Inlet.get_connections = func {
    var v = [];
    me.datasize = 0;
    if(size(me.connections)==0) return v;
    foreach(var k;keys(me.connections))
        append(v,me.connections[k]);
 
    v = sort(v,func(a,b) a.srcobj.start > b.srcobj.start);

    var last = me.destobj.start;
#    var last_end = v[0].srcobj.start+v[0].srcobj.length;
    for(var i=0; i<size(v); i+=1) {
        var con = v[i];
        con.order = i;
        var src = con.srcobj;
        if(i>0) v[i-1].length = src.start-last;
        con.start = src.start-me.destobj.start;
#        con.offset = con.start;
#        if(i==0) con.offset = con.start;
#        else con.offset = src.start-last_end;
#        else con.offset = con.start;
#        else con.offset = src.start-last;
        last = src.start;
#        last_end = last+src.length;
        con.datasize = src.get_datasize(con.outlet);

        con.audiobuf = con.srcobj.outlets[con.outlet].audiobuf;

        if(i==0 and con.start < 0) {
            var res = con.get_resolution();
            if(res>0) {
#                con.offset = math.mod(con.start,res);
                con.first_ev = int(-con.start/res);
                con.datasize -= con.first_ev;
             #FIXME
            } else {
#                var t = con.start;
                for(var j=0; j<con.datasize; j+=1) {
                    var ev = src.get_event(con.outlet,j);
                    if(ev[0]+con.start>=0) break;
#                    if(t>=0) break;
#                    t += ev[0];
                }
                # FIXME: optional clipping.
                # interpolating data should be clipped with src.interpolate()...
#                j -= 1;
                if(j<0) j=0;
#                con.offset = t;
                con.first_ev = j;
                con.datasize -= j;
            }
        } else {
            con.first_ev = 0;
        }

        me.datasize += con.datasize;
    }
    var con = v[-1];
    if(con.start+con.srcobj.length>me.destobj.length) {
        #FIXME: cut con.datasize...
    }
    if(me.destobj.length>0)
        con.length = me.destobj.length-con.start;
    else
        con.length = con.srcobj.length;
    return v;
}
#:: === Inlet.con_finder() ===
#:: Returns a cached connection-finder, which is a function //f(t)// that returns the relevant
#:: connection at time ``t``. As long as ``t`` is not less than it was the last time, the
#:: search will start at the last found connection.
#:: Returns nil if inlet is not connected.
Inlet.con_finder = func {
    var v = me.get_connections();
    var sz = size(v);
    if(sz==0) return nil;
    var ot = 0;
    var i = 1;
    var last = v[0];
    
    var finder = func(t) {
#        if(sz==0) return nil;
#        els
        if(sz==1) return v[0];
        if(t<ot) {
            i=1;
            last = v[0];
        }
        ot = t;
        for(;i<sz;i+=1) {
            if(t<v[i].start) return last;
            last = v[i];
        }
        return last;
    }
    return finder;
}
#:: === Inlet.val_finder(default=nil) ===
#:: Returns a cached value-finder, which is a function //f(t)// that returns
#:: the value at time ``t`` from the connection at time ``t``, or the value of ``default``
#:: if inlet is not connected.
Inlet.val_finder = func(default=nil) {
    var find_con = me.con_finder();
    #FIXME: also cache get_value()...
    if(find_con!=nil)
        return func(t) find_con(t).get_value(t);
    else
        return func default;
}
#:: === Inlet.val_finder_num(default=nil) ===
#:: Returns a cached value-finder, which is a function //f(t)// that returns
#:: the value at time ``t`` from the connection at time ``t``, or the value of ``default``
#:: if inlet is not connected or the value is not a number.
Inlet.val_finder_num = func(default=nil) {
    var find_con = me.con_finder();
    #FIXME: also cache get_value()...
    if(find_con!=nil)
        return func(t) {
            var x = num(find_con(t).get_value(t));
            return x==nil?default:x;
        }
    else
        return func default;
}

#:: == Connection class ==[Connection]
#:: A Connection object holds a connection from a source object and outlet.
#:: It will also hold properties specific for this connection.
var Connection = {};
Connection.new = func(obj,outlet) {
    var o = {parents:[Connection]};
    o.srcobj = obj;
    o.outlet = outlet;
#    o.prop_value = {};
#    o.prop_callback = {};
    o.properties = {};
#    o.resolution = obj.get_resolution(outlet);
#    o.interpolating = obj.get_interpolating(outlet);
#    o.datasize = obj.get_datasize(outlet); #FIXME: this should clip if src is outside dest...
#    o.xpos = 0;
#    o.draw_pos = 0;

#    o.transfunc_str = "";
#    o.transfunc = nil;
#    o.add_prop("transfer func","transfunc_str",func {
#        if(size(o.transfunc_str)) {
#            var err = [];
#            var compfn = func compile(o.transfunc_str, "transfer func");
#            var code = call(compfn, nil, nil, nil, err);
#            if(size(err)) die(err[0]);
#            o.transfunc = code;
#        } else
#            o.transfunc = nil;
#        o.srcobj.update();
#    }).no_eval=1;
    return o;
}
Connection.add_prop = func(name, sym=nil, cb=nil, no_eval=1) {
#    me.prop_callback[name] = cb;
#    me.set_prop(name,val);
    var obj = me;
    if(sym==nil) sym=name;
    if(!contains(me,sym)) me[sym]=nil;
    me.properties[name] = {
        get:func obj[sym],
        set:func(v) {
            obj[sym]=v;
            if(cb!=nil) cb(obj);
        },
        no_eval:no_eval
    }
}
#:: === Connection.set_prop(sym, val) ===
#:: Set property.
Connection.set_prop = ASObject.set_prop;
#:: === Connection.get_prop(sym) ===
#:: Get property.
Connection.get_prop = ASObject.get_prop;
Connection.apply_transfunc = func(val) {
    if(me.transfunc!=nil) {
        var err = [];
        var res=call(me.transfunc,nil,nil,
#            {x:val,math:math,globals:me.srcobj.score.globals},err);
            {x:val,math:math},err);
        if(size(err))
            printerr(utils.stacktrace(err));
        else
            val = res;
    }
    return val;
}
#:: === Connection.get_resolution() ===
#:: Returns the value of ``outlet.resolution`` for this connections
#:: source object and outlet.
Connection.get_resolution = func me.srcobj.outlets[me.outlet].resolution;
#:: === Connection.get_interpolate() ===
#:: Returns the value of ``outlet.interpolate`` for this connections
#:: source object and outlet.
Connection.get_interpolate = func me.srcobj.outlets[me.outlet].interpolate;
#:: === Connection.get_value(t) ===
#:: Get the value of this connections source object and outlet at time ``t``.
Connection.get_value = func(time) {
    time -= me.start;
    var val = me.srcobj.get_value(me.outlet,time);
    return me.apply_transfunc(val);
}
#:: === Connection.get_event(i) ===
#:: Get the event of this connections source object and outlet at index ``i``.
Connection.get_event = func(index) {
    var ev = me.srcobj.get_event(me.outlet,index+me.first_ev);
#    if(index==0) {
#        var ev2 = ev~[];
#        ev2[0] = me.offset;
#        return ev2;
#    }
#    ev=[ev[0]+me.offset,ev[1]];
    ev=[ev[0]+me.start,me.apply_transfunc(ev[1])];
    return ev;
}
Connection.old_get_samples = func(res=nil) {
    return me.srcobj.get_samples(me.outlet,me.length,res);
}
Connection.old_get_events = func {
    return me.srcobj.get_events(me.outlet,me.length);
}

EXPORT=['get_classes','import_classes','Score','ASObject','find_sym','locate_file','dump_descriptions'];
