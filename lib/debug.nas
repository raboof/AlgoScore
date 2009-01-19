# Copyright 2007, 2008, Jonatan Liljedahl
# Heavily based on debug.nas from Nasal.
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

var escape = func(s) {
    var v = split("'",s);
    s="'"~v[0];
    for(i=1;i<size(v);i+=1)
        s~="\'"~v[i];
    s~="'";
}

# Returns the specified object in (mostly) valid Nasal syntax.
# The ttl parameter specifies a maximum reference depth.
var dump = func(o, ttl=16) {
    var ot = typeof(o);
    #if(ot == "scalar") { return num(o)==nil ? sprintf("'%s'", o) : o; }
#    if(ot == "scalar") { return streq(o,o) ? sprintf("'%s'", o) : o; }
#    if(ot == "scalar") { return sprintf(streq(o,o) ? "'%s'" : "%g", o); }
    if(ot == "scalar") { return streq(o,o)?escape(o):sprintf("%g",o); }
    elsif(ot == "nil") { return "nil"; }
    elsif(ot == "vector" and ttl >= 0) {
        var result = "[ ";
	forindex(i; o)
	    result ~= (i==0 ? "" : ", ") ~ dump(o[i], ttl-1);
        return result ~ " ]";
    } elsif(ot == "hash" and ttl >= 0) {
        var ks = keys(o);
        var result = "{ ";
        forindex(i; ks)
            result ~= (i==0?"":", ") ~ ks[i] ~ " : " ~ dump(o[ks[i]], ttl-1);
        return result ~ " }";
    } elsif(ot == "ghost")
        return sprintf("<%s ghost>", ghosttype(o));
    else
        return sprintf("<%s>", ot);
}

var dumpkeys = func(o, ttl=16) {
    var ot = typeof(o);
    if(ot == "scalar") { return sprintf(streq(o,o) ? "'%s'" : "%g", o); }
    elsif(ot == "nil") { return "nil"; }
    elsif(ot == "vector" and ttl >= 0) {
        return "[]";
    } elsif(ot == "hash" and ttl >= 0) {
        var ks = keys(o);
        var result = "{ ";
        forindex(i; ks)
            result ~= (i==0?"":", ") ~ dumpkeys(ks[i]) ~ " : " ~ dumpkeys(o[ks[i]], ttl-1);
        return result ~ " }";
    } elsif(ot == "ghost")
        return sprintf("<%s ghost>", ghosttype(o));
    else
        return sprintf("<%s>", ot);
}
