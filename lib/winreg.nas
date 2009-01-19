import("gtk");

var windows = [];
var callbacks = [];

var add_window = func(name, win, acc="") {
    append(windows,[name,win,acc]);
    foreach(var cb;callbacks)
        cb(name,win,acc);
}
var add_callback = func(cb) {
    append(callbacks,cb);
    foreach(var w;windows) {
        cb(w[0],w[1],w[2]);
    }
}
var get_windows = func windows;

EXPORT=["add_window","add_callback","get_windows"];
