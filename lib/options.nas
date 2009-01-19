# Copyright 2007, 2008, Jonatan Liljedahl
#
# This file is part of AlgoScore.
#
# AlgoScore is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# AlgoScore is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with AlgoScore.  If not, see <http://www.gnu.org/licenses/>.

# Generic option-manager.
#
# - set(name,value)
#   Set a setting to a value.
#
# - get(name)
#   Get the value of a setting.
#
# - set_default_rcfile(fn)
#   Set the default rcfile used by save() and load() when
#   no filename is passed to them.
#
# - save(fn)
#   Save settings to file.
#
# - load(fn)
#   Load settings from file.
#
# - add_notify_callback(name,cb)
#   Add a notify callback for a setting. It will be called when the
#   setting changes. The new value will be passed as an arg.
#   A setting can have multiple callbacks.
#
# - dump()
#   Print the current settings.

#TODO: auto-gui:
#let the options.open_gui() take a settings hash as argument,
#let each option element be:
#{label,value,type,default}
#where type is: string, vector of strings/numbers for combobox,
#numentry, numslider (with min/max), filesave/load (?), etc...
#settings["mtc"]={value:30,type:[25,29,30]}
#one problem is we don't know in which order the settings will be
#drawn...
#another approach would be to only define the options here,
#and have a separate structure to describe the gui,
#like roxlib does... but that ruins the elegant decentralized handling
#of options we have now...
#another way would be to at least group the options, and let the
#gui have a list or notebook to show groups, then perhaps it wouldn't
#matter too much in what order they come?

import("debug");
import("io");
import("utils");

var _settings = {};
var _callbacks = {};
var _defaults = {};
var _rcfile = nil;

var _do_callback = func(name) {
    if(contains(_callbacks,name)) {
        foreach(var cb;_callbacks[name])
            cb(_settings[name]);
    }
}
var _dump_settings = func {
    var s = "";
    foreach(var k; keys(_settings)) {
        s ~= k~" = "~debug.dump(_settings[k])~";\n";
    }
    s;
}
var set_default_rcfile = func(fn) { _rcfile = fn; }
var add_notify_callback = func(name,cb) {
    if(!contains(_callbacks,name))
        _callbacks[name] = [cb];
    else
        append(_callbacks[name],cb);
}
var set = func(name,value) {
#print("setting ",name,"=",value,"\n");
    _settings[name] = value;
    _do_callback(name);
}
var get = func(name) {
    _settings[name];
}
var del = func(name) {
    delete(_settings,name);
}
var get_default = func(name) {
    _defaults[name];
}
var list = func sort(keys(_settings),cmp);

var add_option = func(name,default,cb=nil) {
    if(cb!=nil) add_notify_callback(name,cb);
    _defaults[name] = default;
    if(!contains(_settings,name))
        set(name,default);
    else
        _do_callback(name);
}
var dump = func { print(_dump_settings()); }
var load = func(fn=nil) {
    if(fn==nil) fn=_rcfile;
    if(io.stat(fn)==nil) return;
    run_file(fn,_settings);
    foreach(var k; keys(_settings)) {
        _do_callback(k);
    }
}
var save = func(fn=nil) {
    if(fn==nil) fn=_rcfile;
    var f = io.open(fn,"w");
    io.write(f,_dump_settings());
    io.close(f);
}
