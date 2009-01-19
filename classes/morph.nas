import("algoscore");
import("cairo");
import("palette");
import("math");

var ripol = func(a,b,x,f) {
    var t = typeof(a);
    if(typeof(b)!=t)
        return a; #die("A is not same type as B");
    
    if(t=="scalar")
        return f(a,b,x);
    elsif(t=="vector") {
        var v = [];
        forindex(var i;a)
            append(v,ripol(a[i],b[i],x,f));
        return v;
    } elsif(t=="hash") {
        var h = {};
        foreach(var k;keys(b))
            h[k]=b[k];
        foreach(var k;keys(a))
            h[k]=contains(b,k)?ripol(a[k],b[k],x,f):a[k];
        return h;
    }
}

Morpher = {parents:[algoscore.ASObject]};
Morpher.name = "morph";
Morpher.description =
"<b>Morph between two inputs</b>\n\n"
"Vectors and hashes are handled recursively.\n"
"Vectors must have the same structure.\n"
"Any keys in one hash that are missing in the other are copied.\n"
"If the type of A is not the same as B, the value of A will be returned.\n"
"The <tt>interpolator</tt> property defines the function used for interpolating"
" between numeric values.\n"
"The code runs with the following variables set:\n"
"- <tt>a</tt> : The value of input A.\n"
"- <tt>b</tt> : The value of input B.\n"
"- <tt>x</tt> : The value of input x if connected, else a ramp between 0.0 and 1.0"
" along the length of the object.\n";
Morpher.init = func(o) {
    algoscore.ASObject.init(o);
    o.parents = [Morpher];
    o.new_inlet("A");
    o.new_inlet("B");
    o.new_inlet("x");
    o.new_outlet("out",0,1);
    o.height=16;
    o.interpolator = "(1-x)*a + x*b";
    o.add_obj_prop("interpolator").no_eval=1;
}
Morpher.generate = func {
    me.interpolator_func = compile(me.interpolator,me.get_label()~" interpolator");
    me.get_a = me.inlets.A.val_finder(0);
    me.get_b = me.inlets.B.val_finder(0);
    me.get_x = me.inlets.x.val_finder(nil);
    0;
}
Morpher.get_value = func(out,t) {
    var x = me.get_x(t);
    if(x==nil) x = math.clip(t/me.length,0,1);
    return ripol(me.get_a(t),me.get_b(t),x,func(a,b,x) {
        var ns = new_nasal_env();
        ns.math = math;
        ns.a = a;
        ns.b = b;
        ns.x = x;
        return call(me.interpolator_func,nil,me,ns);
    });
}
Morpher.draw_text = func(cr,x,s) {
    cairo.set_font_size(cr,me.height*0.8);
    cairo.select_font_face(cr,"Mono");
    var ext = cairo.text_extents(cr,s);
    cairo.move_to(cr,x+me.height/2-ext.x_advance/2,me.height/2-ext.y_bearing/2);
    cairo.show_text(cr,s);
}
Morpher.draw = func(cr,ofs,width,last) {
    cairo.set_line_width(cr,1);
    cairo.translate(cr,0.5,0.5);
    palette.use_color(cr,"fg");
    var h = me.height;
    if(ofs==0) {
        me.draw_text(cr,0,"A");
        cairo.rectangle(cr,0,0,h,h);
        cairo.stroke(cr);
        cairo.move_to(cr,h,h/2);
    } else
        cairo.move_to(cr,0,h/2);
    cairo.line_to(cr,int(width)-h,h/2);
    if(last) {
        var x = int(width)-h;
        me.draw_text(cr,x,"B");
        cairo.rectangle(cr,x,0,h,h);
    }
    cairo.stroke(cr);
    cairo.move_to(cr,int(width/2)-9.5,me.height/2-5);
    cairo.rel_line_to(cr,0,10);
    cairo.rel_line_to(cr,20,-5);
    cairo.close_path(cr);
    cairo.fill(cr);

}
EXPORT=["Morpher","ripol"];

