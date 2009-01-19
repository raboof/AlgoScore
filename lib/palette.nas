import("cairo");

var colors = {};
var dashes = {};

#var add_color = func(name, color) {
#    colors[name] = color;
#}

var use_color = func(cr, name) {
    var clr = colors[name];
    call(size(clr)==3?cairo.set_source_rgb:cairo.set_source_rgba,[cr]~clr);
}

var use_color_a = func(cr, name, a) {
    var clr = subvec(colors[name],0,3)~[a];
    call(cairo.set_source_rgba,[cr]~clr);
}

var use_dash = func(cr, name) {
    cairo.set_dash(cr, dashes[name]);
}

var load_style = func(fn) {
    var ns = {};
    run_file(fn,ns);
    colors = ns.colors;
    dashes = ns.dashes;
}

var use_style = func(cr, name) {
    use_color(cr,name);
    use_dash(cr,name);
}

EXPORT = ["load_style","use_color","use_color_a","use_dash","use_style"];
