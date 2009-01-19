import("gtk");

var _id = 0;
var _procs = {};

var add_proc = func(cb,enable=1) {
    _id += 1;
    _procs[_id] = {cb:cb,enable:enable};
    return _id;
}

var enable_proc = func(id,state=1) {
    _procs[id].enable = state;
}

var remove_proc = func(id) {
    delete(_procs,id);
}

var _tmr_cb = func {
    foreach(var k;keys(_procs)) {
        var p=_procs[k];
        if(p.enable) p.enable=p.cb();
    }
    return 1;
}

gtk.timeout_add(200,_tmr_cb);
