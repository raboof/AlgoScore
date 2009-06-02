# Copyright 2006, Andrew Ross
# Original file distributed as part of Nasal
# Modifications for AlgoScore 2007, 2008, Jonatan Liljedahl
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

# FIXME: the cache of stored modules is stored by module name, but it
# really should be stored by filename.  This is a problem for web
# apps, where you might have two apps on the same interpreter with a
# module named "config"

# This is the top-level "driver" file containing the module import
# code for Nasal programs.  Call this file from your C code to get
# back a hash table for use in binding new functions.  You can use it
# directly, clone it to make sandboxed environments, or (in a script)
# call new_nasal_env() to create such a cloned environment even
# without access to the original hash.
#
# MODULES:
#
# Nasal modules are really simple:
#
# + Users import modules with the import function.  The first argument
#   is a string containing the module name.  Any further arguments are
#   symbols to be imported into the caller's namespace in addition to
#   the module hash.  This code:
#       import("math", "sin", "cos");
#   will import the math library as a hash table named "math" in the
#   local namespace, and also set local variables for the sin and cos
#   functions.  A single "*" as the symbol to import is shorthand for
#   "import everything into my namespace".
#
# + Module files end with ".nas" and live either in the same directory
#   as the importing file (detected dynamically), the same directory
#   as driver.nas (detected dynamically), or in the current directory,
#   in that order of preference.  (This search path could easily be
#   made to include user directories, e.g. $NASAL_LIB, in the future).
#
# + Module files are run once, the first time user code imports them.
#   The local variables defined during that script run become the
#   module namespace, with a few exceptions:
#   + Only symbols that reference "shallow" objects (not vectors or
#     hashes) are exported by default.
#   + Symbols begining with an understore (_) are not exported by default.
#   + The special "arg" and "EXPORT" symbols are not exported by default.
#
#  + Modules that want to break these rules can, by defining an EXPORT
#    vector in their local namespace containing the precicse list of
#    symbol strings to export.
#
#  + If there is a built-in module (i.e. math, regex, etc...) already
#    defined, then the symbols defined there are available as local
#    variables at the time the module script begins running.  If there
#    is no module script, then the built-in symbols are used as-is.
#
#  + Files run at the end of this driver script, or more generally
#    inside a new_nasal_env() cloned environment, are physically
#    separated from each other and do not see each other's data,
#    except where modules choose to export shared data via their
#    symbol tables or function results.
#
# SECURITY NOTES:
#
#  + If code is allowed access to bind(), caller() and closure(), it
#    will still be able to follow function references to module data.
#    Applications that want to sandbox untrusted scripts for security
#    reasons should remove these symbols from the namespace returned
#    from new_nasal_env() or replace them with wrapped versions that
#    check caller credentials (one example: limit code to examining
#    and binding to functions defined in the same file or under the
#    same directory, etc...).
#
#  + The parents reference on objects is user-visible, which breaks
#    the security encapsulation above.  Currently, this means that OOP
#    is disallowed when class objects need to be shared between
#    untrusted modules.  That may not be a bad idea, though, as
#    security-concious interfaces should be thin and minimal.  Clever
#    implementations can still provide OOP interfaces, but they must
#    do it without referencing module data in the parents array.

# Note: this implementation is currently unix-specific (including
# cygwin, of course), but needn't be with some portability work to
# getcwd() and the directory separator.

# Construct a valid path string for the directory containing this file
var dirname = func(path) {
    var lastslash = 0;
    for(var i=0; i<size(path); i+=1)
	if(path[i] == `/`)
	    lastslash = i;
    path = substr(path, 0, lastslash);
    if(!lastslash or path[0] != `/`)
	path = unix.getcwd() ~ "/" ~ path;
    return path;
}

var clone_hash = func(h) {
    var result = {};
    foreach(k; keys(h))
	result[k] = h[k];
    return result;
}

# Duplicated from the io library, which we can't import here:
var readfile = func(file) {
    var sz = io.stat(file)[7];
    var buf = bits.buf(sz);
    io.read(io.open(file), buf, sz);
    return buf;
}

var new_nasal_env = func { clone_hash(core_env) }

# Reads and runs a file in a cloned version of the standard library
# Simplified by Jonatan Liljedahl
var run_file = func(file, syms=nil, args=nil) {
    var err = [];
#    var compfn = func { compile(readfile(file), file); };
#    var code = call(compfn, nil, nil, nil, err);
#    if(size(err))
#	die(sprintf("%s in %s", err[0], file));
#    var code = call(compile,[readfile(file), file]);
#print_stderr("reading ",file,"\n");
    var code = compile(readfile(file), file);
#    if(size(err))
#	die(sprintf("%s in %s", err[0], file));

    code = bind(code, new_nasal_env(), nil);
    call(code, args, nil, syms);
#    call(code, args, nil, syms, err);
#    if(size(err) and err[0] != "exit") {
#	print(sprintf("Runtime error: %s\n", err[0]));
#	for(var i=1; i<size(err); i+=2)
#	    print(sprintf("  %s %s line %d\n", i==1 ? "at" : "called from",
#			     err[i], err[i+1]));
#    }
}

var module_stat = {};

var find_mod = func(mod, prefdir, ext) {
    var file = nil;
    var check = prefdir ~ "/" ~ mod ~ ext;
    if(io.stat(check) != nil) {
        file = check;
    } else {
        foreach(dir; module_path) {
            check = dir ~ "/" ~ mod ~ ext;
            if(io.stat(check) != nil) {
                file = check;
                break;
	        }
        }
    }
    return file;
}

# Locates a module file, runs and loads it
var load_mod = func(mod, prefdir) {
    var dlfile = find_mod(mod, prefdir, ".so");
    var file = find_mod(mod, prefdir, ".nas");
    var iscore = contains(core_modules, mod);
    if(file == nil and dlfile == nil and !iscore) die("cannot find module: " ~ mod);
    var syms = iscore ? core_modules[mod] : (dlfile != nil ? load_plugin(dlfile) : {});
    if(file != nil) run_file(file, syms);

    # save the mtime for later checks...
    if(file != nil) module_stat[mod] = [file,io.stat(file)[9]];

    # Build a table of symbols to export, either the contents of the
    # EXPORT list or the shallow, non-internal, non-special symbols.
    var modexp = {};
    if(contains(syms, "EXPORT") and typeof(syms["EXPORT"]) == "vector") {
        foreach(s; syms["EXPORT"]) {
            if(contains(syms, s)) {
                modexp[s] = syms[s];
            }
        }
    } else {
    	foreach(k; keys(syms)) {
    	    if(typeof(k) != "scalar" or size(k) == 0) continue;
    	    if(k[0] == `_` or k == "arg" or k == "EXPORT") continue;
    	    if(typeof(syms[k]) == "hash") continue;
    	    if(typeof(syms[k]) == "vector") continue;
    	    modexp[k] = syms[k];
    	}
    }
    loaded_modules[mod] = modexp;
}

# check if a module file has changed since last time.
var module_changed = func(mod) {
    if(!contains(module_stat,mod)) return 0;
    var oldstat = module_stat[mod];
    var mtime = io.stat(oldstat[0])[9];
    if(mtime != oldstat[1]) return 1;
    else return 0;
}

# This is the function exposed to users.
var import = func(mod, imports...) {
    if(!contains(loaded_modules, mod) or module_changed(mod)) {
        var callerfile = caller()[2];
        load_mod(mod, dirname(callerfile));
    }
    var caller_locals = caller()[0];
    var module = clone_hash(loaded_modules[mod]);
    caller_locals[mod] = module;
    if(size(imports) == 1 and imports[0] == "*") {
        foreach(sym; keys(module)) caller_locals[sym] = module[sym];
    } else {
        foreach(sym; imports) {
            if(contains(module, sym)) caller_locals[sym] = module[sym];
            else die(sprintf("No symbol '%s' in module '%s'", sym, mod));
        }
    }
}

# The default module loading path
# FIXME: read a NASAL_LIB_PATH environment variable or whatnot
var module_path = [dirname(caller(0)[2]), "."];

# Tables of "core" (built-in) functions and modules available, and a
# table of "loaded" modules that have been imported at least once.
var core_env = {};
var core_modules = {};
var loaded_modules = {};

# Assuming our "outer scope" is indeed the naStdLib() hash, grab the
# symbols therein.
var outer_scope = closure(caller(0)[1]);
foreach(x; keys(outer_scope)) {
    var t = typeof(outer_scope[x]);
    # Addition: also import scalars
    if(t == "func" or t == "scalar") { core_env[x] = outer_scope[x]; }
    elsif(t == "hash") { core_modules[x] = outer_scope[x]; }
}

# Add import() and new_nasal_env().
core_env["import"] = import;
core_env["new_nasal_env"] = new_nasal_env;

#--------------------- AlgoScore additions ---------------------
core_env.run_file = run_file;
core_env.add_core_symbol = func(s,v) { core_env[s] = v; }
core_env.lib_dir = dirname(caller(0)[2]);
core_env.dirname = dirname;
core_env.cmdline_args = arg;
core_env.add_module_path = func(d,index=nil) {
    if(index!=nil) {
        module_path[index]=d;
        return;
    }
    var index = size(module_path);
    append(module_path,d);
    return index;
}

if(size(arg) and arg[0]=="--script") {
    run_file(arg[1], {}, subvec(arg, 2));
    return core_env;
}

import("options");
import("unix");
core_env.app_dir = unix.getcwd();
options.set_default_rcfile(unix.getenv("HOME") ~ "/.algoscorerc");
options.load();
import("top_ui");
#wd_init();
top_ui.start();


