import("gtk");

var w = gtk.Window("title","Progress","window-position","center","border-width",10,"modal",1,"type-hint","dialog");
w.connect("delete-event",func 1);

var p = gtk.ProgressBar();
var l = gtk.Label();
var b = gtk.Button("use-stock",1,"label","gtk-cancel");
var did_cancel = 0;
b.connect("clicked",func did_cancel=1);

var box = gtk.VBox("spacing",10);
box.add(l);
box.add(p);
box.add(b);
w.add(box);

var start = func(label) {
    did_cancel = 0;
    w.show_all();
    update(0,label);
}

var update = func(frac,label=nil) {
    if(frac>1) frac=1;
    elsif(frac<0) frac=0;
    p.set("fraction",frac);
    if(label!=nil) l.set("label",label);
    gtk.main_iterate_while_events();
    return did_cancel;
}

var done = func w.hide();

EXPORT = ["start","update","done"];
