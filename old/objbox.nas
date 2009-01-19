import("gtk");

var classnames = ["foo","bar","xyz","obj","hej","hopp","saab","tur","koop","tratt"];

# also show class.description for selected object.

# where should available classes be stored?
# perhaps we need a class register:
# algoscore.register_class = func(class) {
#   class_store[class.name] = class;
# }
# at startup we import all classes from all files in
# AlgoScore/classes/*
# simply do a run_file() on each one with a namespace that
# exports register_class()...
#
# then in the gui we do this to add objects to the score:
# obj = algoscore.classes["lfo1"].new(score);

var store = gtk.ListStore_new("gchararray");
var view = gtk.TreeView("model",store);
var c = gtk.TreeViewColumn("title","Classes","expand",1);
c.add_cell(gtk.CellRendererText(),0,"text",0);
view.append_column(c);

foreach(v;classnames)
    store.set_row(store.append(),0,v);

view.connect("row-activated",func(wid,path,col) {
    print(store.get_row(path,0),"\n");
    w.hide();
    w.destroy();
});
    
var w = gtk.Window("title","Create object","default-height",300,"default-width",200);
var sc = gtk.ScrolledWindow("hscrollbar-policy","never");
sc.add(view);
#var b = gtk.VBox();
#var x = gtk.Expander("label","Test");
#x.add(gtk.Label("label","Hi there\nthis is a test\nhope it works..."));
#b.pack_start(x,0);
#b.add(sc);
#w.add(b);
w.add(sc);
w.show_all();

gtk.main();
