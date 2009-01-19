import("gtk");

var do_popup_menu = func(choices,cb,button,time=nil) {
    var m = gtk.Menu();
    var value = nil;
    m.connect("selection-done",func {
        cb(value);
        m.destroy();
    });
    foreach(var c; choices) {
        var i = gtk.MenuItem();
        i.add(gtk.Label("label",c));
        i.show_all();
        m.add(i);
        i.connect("activate",func(item,x) value = x, c);
    }
    if(time!=nil) m.popup(button, time);
    else m.popup(button);
}

var w = gtk.Window("border-width",20);
var e = gtk.EventBox();
e.add(l = gtk.Label("label","popup here"));
w.add(e);
e.set("events",{"button-press-mask":1},"can-focus",1);
var values = ["foo","bar","zoo"];
var my_cb = func(x) {
    print("selected ",x,"\n");
}
e.connect("button-press-event",func(wid,ev) {
    do_popup_menu(values, my_cb, ev.button, ev.time);
});
w.show_all();
gtk.main();
