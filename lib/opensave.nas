import("gtk");
import("score_ui");
import("utils");
import("io");
import("options");
import("globals","*");

var curr_filename = nil;
var fn_change_cb = func nil;

var set_curr_file = func(f) {
    curr_filename = f;
    fn_change_cb(f);
}

var save = func {
    var d = gtk.FileChooserDialog("title","Save score","action","save",
        "transient-for",globals.top_window,"window-position","center-on-parent");
    if(curr_filename!=nil) d.set_filename(curr_filename);
#    else {
#        d.set_current_folder(unix.getcwd()~"/projects");
#        d.set_current_name("new_project");
#    }
    var score = score_ui.get_score();
    d.add_buttons("gtk-cancel",-2,"gtk-ok",-3);
    d.connect("response",func(wid,id) {
        if(id==-3) {
#            algoscore.set_curr_filename(curr_filename=d.get_filename());
            set_curr_file(d.get_filename());
            score.save_to_file(curr_filename);
            d.hide();
            d.destroy();
        } elsif(id==-2) {
            d.hide();
            d.destroy();
        }
    });
    d.show();
}

var open_file = func(fn) {
    set_curr_file(fn);
    score_ui.get_score().load_from_file(fn);
    score_ui.zoom_fit_all();
    score_ui.scroll_home_y();
}

var open = func(fn=nil) {
    if(fn!=nil) {
        open_file(fn);
        return;
    }
    var d = gtk.FileChooserDialog("title","Open project","action","open",
        "transient-for",globals.top_window,"window-position","center-on-parent");
#    d.set_current_folder(unix.getcwd()~"/projects");
    d.add_buttons("gtk-cancel",-2,"gtk-ok",-3);
    d.connect("response",func(wid,id) {
        if(id==-3) {
            open_file(d.get_filename());
            d.hide();
            d.destroy();
        } elsif(id==-2) {
            d.hide();
            d.destroy();
        }
    });
    d.show();
}

var set_fn_cb = func(f) fn_change_cb = f;

EXPORT=["save","open","set_fn_cb"];
