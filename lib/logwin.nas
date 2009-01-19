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
import("options");
import("score_ui");
import("winreg");
import("algoscore");
import("utils");

#var max_log_size = nil;
#options.add_option("max_log_size",10000,func(v) max_log_size=v);

var histsize = 128;
var histbuf = setsize([],histsize);
var histget = 0;
var histptr = 0;

var add_hist = func(s) {
#   var old_s = histbuf[histptr>0?histptr-1:histsize-1];
#   var x = (old_s!=nil && s!=nil)? strcmp(old_s,s):1;
    if(s!=nil and size(s)) {
        histbuf[histptr]=s;
        histptr += 1;
        if(histptr == histsize) histptr = 0;
    }
    histget=histptr;
}

var get_hist = func(i) {
    var new=histget+i;
    if(new<0) new=histsize-1;
    elsif(new==histsize) new=0;
    if(histbuf[new]!=nil) histget=new;
    if(i>0 and new==histptr) {
        histget=histptr;
        return "";
    }
    return histbuf[histget] or "";
}

var cmd_env = nil;

var cmdwin = gtk.Window("title","AlgoScore console");
cmdwin.set("default-width",460,"default-height",250);
cmdwin.connect("delete-event",func cmdwin.hide());

winreg.add_window("Console",cmdwin,"<Alt>l");

var pane = gtk.VBox();
cmdwin.add(pane);

var logtext = gtk.TextView("name","monotext");
logtext.set("editable",0,"wrap-mode","word-char","left-margin",4,"right-margin",4);

var sw = gtk.ScrolledWindow("hscrollbar-policy","never");
sw.add(logtext);
pane.pack_start(sw);

var print = func(args...) {
#    var buf = logtext.get("buffer");
#    var txt = buf.get("text");
#    foreach(var s;args)
#        txt ~= s;
#    if(size(txt)>max_log_size)
#        txt = substr(txt,-max_log_size);
#    buf.set("text",txt);
    logtext.move_cursor("buffer-ends",1,0);
    foreach(s;args)
        logtext.insert(s);
    logtext.scroll_to_cursor();
#    show();
    nil;
}
var printf = func print(call(sprintf,arg));
add_core_symbol("printf",printf);
set_print_handler(print);

var error_tag = logtext.create_tag();

options.add_option("error_log_color","red",func(v) {
    error_tag.set("weight",700,"weight-set",1,"foreground",v,"foreground-set",1);
});

var printerr = func(args...) {
#    utils.msg_dialog("Error",s,"warning");
    logtext.move_cursor("buffer-ends",1,0);
    foreach(s;args)
        logtext.insert_with_tag(s,error_tag);
    logtext.scroll_to_cursor();
    show();
    cmdwin.raise();
}

set_printerr_handler(printerr);
#add_core_symbol("printerr",printerr);

#set_printerr_handler(func(s) { print(s); cmdwin.raise(); });

var logline = 1;

var parse_cmd = func(wid) {
    var text = wid.get("text");
    wid.set("text","");

    if(cmd_env==nil) cmd_env = new_nasal_env();
#    cmd_env.globals = score_ui.get_score().globals;
    cmd_env.score = score_ui.get_score();
    cmd_env.algoscore = algoscore;
    
    add_hist(text);

    print("<"~logline~"> "~text~"\n");
    
    var err = [];
    var f = call(func compile(text,"cmdline <"~logline~">"),nil,nil,nil,err);
    if(size(err)) {
        print(err[0],"\n");
        return;
    }
    logline += 1;
    f = bind(f,cmd_env,nil);
#    wd_set_current("cmdline");
    result = call(f,nil,nil,cmd_env,err);
#    wd_set_current();
    if(size(err)) {
#        printf("%s at %s line %d\n", err[0], err[1], err[2]);
#        for(var i=3; i<size(err); i+=2)
#            printf("  called from %s line %d\n", err[i], err[i+1]);
        printerr(utils.stacktrace(err));
        return;
    }
    if(result!=nil) print(debug.dump(result,3),"\n");
}

var key_cb = func(wid,ev) {
    var hist = nil;
    if(ev.keyval_name == "Up")
        hist = get_hist(-1);
    elsif(ev.keyval_name == "Down")
        hist = get_hist(1);
    elsif(ev.state["control-mask"]==1 and ev.keyval_name == "l") {
        logtext.get("buffer").set("text","");    
        return 1;
    }

    if(hist!=nil) {
        wid.set("text",hist);
        wid.move_cursor("buffer-ends",1,0);
        return 1;
    }
    return 0;
}

var box = gtk.HBox();

var prompt = gtk.Entry("name","monotext");
prompt.connect("activate",parse_cmd);
prompt.connect("key-press-event",key_cb);

#box.pack_start(prompt);
#var b = gtk.Button("use-stock",1,"label","gtk-clear");
#b.connect("clicked",func {
#    logtext.get("buffer").set("text","");
#});
#box.pack_start(b,0);

#pane.pack_end(box,0);
pane.pack_end(prompt,0);

logtext.set("events",{
    "enter-notify-mask":1,
});

logtext.connect("enter-notify-event",func prompt.grab_focus());

var show = func { cmdwin.show_all(); }
var focus = func prompt.grab_focus();

var get_ns = func cmd_env;

EXPORT=["show","focus", "get_ns"];
