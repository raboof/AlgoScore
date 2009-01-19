import("gtk");
import("debug");

# TODO: detect two-key-press:
# we need to see if any other key was pressed when a new key is pressed,
# but before hold timeout!
# we must do this in the key-press-event handler, right?
# if another key is also pressed but not hold (state==1) then.. what?
# and then at the callback, create a list of currently pressed keys and
# match it...?
# and then only match this list and not the single key (when size(v)>1)

# Handle double-press, now it produces a press, hold, release sequence...
# We should at least ignore it or produce two press events...
# We might need to keep track of the timeout ID, etc...?

var key_state = {};
#var key_sym = {};
var key_callback = func(key,state) {
#    print(state,": ",key,"\n");
#    var v=[];
#    foreach(var k;keys(key_state)) {
#        if(key_state[k]!=nil)
#            append(v,key_sym[k]);
#    }
#    print(debug.dump(v),"\n");
    var s2 = state;
    if(s2=='release') s2='hold';
    foreach(var a;actions) {
        if(a[1]==key and a[2]==s2)
            a[0](key,state);
    }
}

var actions = nil;

var setup = func(x,a) {
    var e = x.get("events");
    e["key-press-mask"] = 1;
    x.set("events",e,"can-focus",1);
    actions = a;
    x.connect("key-press-event",func(wid,ev) {
#        key_sym[ev.hardware_keycode]=ev.keyval_name;
        if(key_state[ev.hardware_keycode]==nil) {
            key_state[ev.hardware_keycode]=1;
            gtk.timeout_add(200,func {
                var state = key_state[ev.hardware_keycode];
                if(state==1) {
                    key_callback(ev.keyval_name,"hold");
                    key_state[ev.hardware_keycode] = 2;
                }
                return 0;
            });
        }
    });
    x.connect("key-release-event",func(wid,ev) {
        if(key_state[ev.hardware_keycode]==2)
            key_callback(ev.keyval_name,"release");
        elsif(key_state[ev.hardware_keycode]==1)
            key_callback(ev.keyval_name,"press");
        key_state[ev.hardware_keycode]=nil;
    });
}

EXPORT = ["setup"];

# setup(widget, actions) where actions is a list of
# [func(keyname, state) ..., keyname, state]

############### TEST ################

var test = func {
    var my_actions = [
        [func(k,x) print("foo-press: ",k,x,"\n"), 'a', 'press'],
        [func(k,x) print("bar-press: ",k,x,"\n"), 's', 'press'],
        [func(k,x) print("foo-hold: ",k,x,"\n"), 'a', 'hold'],
    ];

    w = gtk.Window("border-width",20);
    e = gtk.EventBox();
    e.add(l = gtk.Label("label","Press keys here..."));
    w.add(e);
    setup(e,my_actions);
    w.show_all();
    gtk.main();
}
