import("algoscore");
import("cairo");
import("palette");
import("debug");

BlkView = { parents:[algoscore.ASObject] };
BlkView.name = "block_view";
BlkView.init = func(o) {
    algoscore.ASObject.init(o);
    o.parents = [BlkView];
    o.new_inlet("events");
    o.block_text = "debug.dump(ev)";
    o.add_obj_prop("block_text").no_eval=1;
    o.height = 30;
    o.font_size = 10;
    o.add_obj_prop("font_size");
}
BlkView.generate = func {
    me.text_getter = compile(me.block_text,me.get_label()~" block_text getter");
    me.con_list = me.inlets.events.get_connections();
    0;
}
BlkView.draw = func(cr,ofs,width,last) {
    cairo.set_line_width(cr,1);
    cairo.translate(cr,0.5,0.5);
    palette.use_color(cr,"fg");
    var ns = new_nasal_env();
    cairo.move_to(cr,0,0);
    cairo.rel_line_to(cr,width,0);
    cairo.move_to(cr,0,me.height);
    cairo.rel_line_to(cr,width,0);
    cairo.stroke(cr);
    cairo.translate(cr,-ofs,0); #FIXME

    cairo.set_font_size(cr,me.font_size);
    cairo.select_font_face(cr,"Mono");

    foreach(c;me.con_list) {
        for(i=0;i<c.datasize;i+=1) {
            var ev = c.get_event(i);
            var (t,val) = ev;
            var x = int(me.score.time2x(t));
            cairo.move_to(cr,x,0);
            cairo.rel_line_to(cr,0,me.height);
            cairo.stroke(cr);
            ns.ev = ev;
            var txt = call(me.text_getter,nil,me,ns);
            var ext = cairo.text_extents(cr,txt);
            cairo.move_to(cr,x+1,me.height/2-ext.y_bearing/2);
            cairo.show_text(cr,txt);
            
        }
    }
}


EXPORT=["BlkView"];
