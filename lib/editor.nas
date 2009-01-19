import("options");
import("utils");
import("unix");

# TODO: add simple built-in texteditor...
# for external editor:
# add possibility to create tmp-file, and re-use it
# each time? like open_file() with no arg returns tmp filename...
# also timer who polls file mtime and callbacks when it has changed.
# or perhaps have an open_string() and pass it a string, which is automatically
# copied to tmp-file.. we still need to return an ID though...

if(platform=="macosx") {
    var _edit_cmd = "open -e"
} else {
    var _edit_cmd = unix.getenv("EDITOR");
}

options.add_option("external_editor",_edit_cmd);

var open_file = func(fn) {
    var prog = options.get("external_editor");
    if(prog==nil) {
        utils.msg_dialog("No editor",
            "You have not set an external editor application, see preferences.",
            "warning");
        return;
    }
    unix.spawn(sprintf("%s %s",prog,fn));
}
