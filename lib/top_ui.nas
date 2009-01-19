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
import("algoscore");
import("io");
import("unix");
import("globals","*");

options.add_option("theme_file", "default", func(f) {
    var path = algoscore.locate_file(f~'.theme');
    if(path!=nil) gtk.rc_parse_string(io.readfile(path));
});

gtk.set_default_icon_from_file(app_dir~"/as_icon.png");

var title_base = "AlgoScore ";

var w = gtk.Window("title",title_base,"border-width",0);

globals.top_window = w;

import("logwin");
import("utils");
import("score_ui");
import("winreg");
import("opensave");
import("outbus");
import("browser");
import("playbus");

opensave.set_fn_cb(func(f) w.set("title",title_base ~ f));

options.add_option("window_size",[600,400],func(v) {
    w.set("default-height",v[1],"default-width",v[0]);
});

var quit = func {
#    if(score_ui.has_changed())
        utils.confirm_dialog(
            "Quit?",
            "There might be unsaved data.\nReally quit AlgoScore?",
            gtk.main_quit);
#    else
#        gtk.main_quit();
    return 1;
}

w.connect("delete-event",quit);

var box = gtk.VBox();

var uixml = '
<ui>
 <menubar name="Menu">
  <menu action="FileMenu">
   <menuitem action="New"/>
   <menuitem action="Open"/>
   <menuitem action="Save"/>
   <separator/>
   <menuitem action="Print"/>
   <separator/>
   <menuitem action="Export"/>
   <separator/>
   <menuitem action="UpdCls"/>
   <menuitem action="Prefs"/>
   <separator/>
   <menuitem action="Quit"/>
  </menu>
  <menu action="ScoreMenu">
   <menuitem action="ScoreProps"/>
   <menuitem action="AutoEnd"/>
   <menuitem action="UpdatePending"/>
   <menuitem action="StopUpdate"/>
   <separator/>
   <menuitem action="ReJack"/>
  </menu>
  <menu action="WinMenu">
  </menu>
  <menu action="HelpMenu">
   <menuitem action="About"/>
   <menuitem action="Help"/>
  </menu>
 </menubar>
</ui>';

var actiongroup = gtk.ActionGroup("name","AS");

actiongroup.add_action(gtk.Action("name", "FileMenu", "label", "_File"));
actiongroup.add_action(gtk.Action("name", "WinMenu", "label", "_Windows"));
actiongroup.add_action(gtk.Action("name", "ScoreMenu", "label", "_Score"));
actiongroup.add_action(gtk.Action("name", "HelpMenu", "label", "_Help"));

var open_help = func(fn) {
    var uri = "file://"~app_dir~"/Help/"~fn;
    browser.open_uri(uri);
}

var show_about = func {
    var txt =
"<span size=\"x-large\"><b>AlgoScore</b></span>\n\n"
"<i>Copyright 2007, 2008 Jonatan Liljedahl</i>\n\n"
"This program is released under the terms of the GNU General "
"Public License version 3 or any later version. "
"See <tt>COPYING</tt> for details.";
    var close = func { w.hide(); w.destroy(); }
    var img = gtk.Image("file",app_dir~"/as_icon.png");
    var w = gtk.Window("title","About AlgoScore","border-width",10);
    w.connect("delete-event",close);
    var box = gtk.VBox("spacing",10);
    box.pack_start(img);
    box.pack_start(gtk.HSeparator());
    var l = gtk.Label("wrap",1,"use-markup",1,"justify","fill","width-chars",40);
    l.set("label",txt);
    box.pack_start(l);
    var box2 = gtk.HBox();
    var www = "http://kymatica.com/algoscore";
    var b = gtk.Button("label",www);
    b.connect("clicked",func browser.open_uri(www));
    var l = gtk.Label("label","Website:");
    box2.pack_start(l);
    box2.pack_start(b);
    box.pack_start(box2,0);
    var b = gtk.Button("use-stock",1,"label","gtk-close");
    b.connect("clicked",close);
    box.pack_start(gtk.HSeparator());
    box.pack_start(b,0);
    w.add(box);
    w.show_all();
}

var new_score = func {
    utils.confirm_dialog(
        "New?",
        "There might be unsaved data.\nReally clear score?",
        func {
            var s = score_ui.get_score();
            s.destroy_all();
            s.init(s);
            s.queue_draw();
        }
    );
}

var actions = [
["New","_New","gtk-new","<Ctrl>n", new_score],
["Open","_Open","gtk-open","<Ctrl>o",func opensave.open()],
["Save","_Save","gtk-save","<Ctrl>s",func opensave.save()],
["Quit","_Quit","gtk-quit","<Ctrl>q",quit],
["UpdCls","_Update classes", "gtk-refresh","",func algoscore.import_classes()],
["Prefs","_Preferences","gtk-preferences","",func {
        import("prefs_ui");
        prefs_ui.show();
    }],
#["Log","Show Console","gtk-info","",logwin.show],
["Print","Print to file", "gtk-print", "<Ctrl>p", score_ui.print_dialog],
["ScoreProps","Score properties","gtk-properties","",score_ui.edit_score_props],
["AutoEnd","Endmark to last obj","gtk-goto-last","<Alt>e",score_ui.endmark_to_last],
["UpdatePending","Update pending","gtk-refresh","<Ctrl>u",score_ui.update_pending],
["StopUpdate","Stop background updates","gtk-stop","<Ctrl>k",outbus.cancel_all],
["Export","Export bus","gtk-save","",outbus.export_bus],
["About","About","gtk-about","",show_about],
["Help","Users manual","gtk-help","",func open_help("algoscore-manual.html")],
["ReJack","Reconnect JACK","gtk-connect","",func if(playbus.init()==1) outbus.reconnect_all()],
];

foreach(a;actions) {
    var x = gtk.Action("name",a[0],"label",a[1],"stock-id",a[2]);
    actiongroup.add_action(x,a[3]);
    x.connect("activate",a[4]);
}

var uim = gtk.UIManager();
uim.insert_action_group(actiongroup, 0);
uim.add_ui(uixml);
w.add_accel_group(uim.get_accel_group(uim));

winreg.add_callback(func(name,win,acc="") {
    var s = '<ui><menubar name="Menu"><menu action="WinMenu"><menuitem action="';
    s ~= name~"Action";
    s ~= '"/></menu></menubar></ui>';
    uim.add_ui(s);
    var x = gtk.Action("name",name~"Action","label",name);
    actiongroup.add_action(x,acc);
    x.connect("activate",func {
        win.show_all();
        win.raise();
    });
});

if(platform=="macosx") {
    ige_mac_menu_set_menu_bar(uim.get_widget("/Menu").object);
    ige_mac_menu_set_quit_menu_item(uim.get_widget("/Menu/FileMenu/Quit").object);
    ige_mac_menu_add_menu_item(uim.get_widget("/Menu/FileMenu/Prefs").object);
} else {
    box.pack_start(uim.get_widget("/Menu"),0);
}
box.pack_start(score_ui.init());

w.add(box);
w.show_all();

var make_user_dir = func {
#    var cancel_cb = func {
#        options.set("user_data_dir","");
#        options.save();
#        init_stuff();
#    }
    utils.confirm_dialog("No userdata folder",
        "AlgoScore didn't find a folder for custom userdata,\n"
        "this is probably because you have not created one yet.\n"
        "Click OK to create one, a dialog for setting the name\n"
        "and location of the folder will appear.",func {
            var d = gtk.FileChooserDialog("title","Save score","action","create-folder");
            d.set_current_name("algoscore_data");
            d.set_current_folder(unix.getenv("HOME"));
            d.add_buttons("gtk-cancel",-2,"gtk-ok",-3);
            d.connect("response",func(wid,id) {
                if(id==-3) {
                    var dir = d.get_filename();
                    unix.mkdir(dir);
                    unix.mkdir(dir~"/lib");
                    unix.mkdir(dir~"/classes");
                    options.set("user_data_dir",dir);
                    options.save();
                    d.hide();
                    d.destroy();
                    init_stuff();
                } elsif(id==-2) {
                    d.hide();
                    d.destroy();
#                    cancel_cb();
                    init_stuff();
                }
            });
            d.show();
        },
        init_stuff);    
}

logwin.show();

var init_stuff = func {
    algoscore.import_classes();
    if(size(cmdline_args)) opensave.open(cmdline_args[0]);
}

var start = func {
    print(
"AlgoScore\n"
"Copyright 2007, 2008, Jonatan Liljedahl\n"
"Released under the terms of GNU GPL v.3 or later,\n"
"see COPYING for more details.\n\n");
    if(io.stat(options.get("user_data_dir"))==nil) {
        make_user_dir();
    } else
        init_stuff();
    gtk.main();
    score_ui.get_score().destroy_all();
}

EXPORT=["start"];
