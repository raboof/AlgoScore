import("gtk");

var score = nil;

var set_score = func(s) score = s;

var edit = func() {
    if(score==nil) return;
    var w = gtk.Window("title","score metadata","border-width",8);
    w.connect("delete-event",func w.hide());
    var box = gtk.VBox("spacing",8);

    foreach(var m;keys(score.metadata)) {
        var b = gtk.HBox("spacing",4);
        var l = gtk.Label("label",m);
        var e = gtk.Entry("text",score.metadata[m]);
        b.pack_start(l);
        b.pack_start(e);
        box.pack_start(b);
        
        e.connect("changed",func {
            score.me
        });
    }

    w.show_all();
    w.raise();
}

EXPORT = ["edit","set_score"];
