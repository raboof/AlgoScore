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

import("math");

var new = func(sz) { setsize([],sz); }

var fill = func(v,x=0) {
    if(typeof(v)=="scalar")
        v = setsize([],v);
    forindex(var i;v) v[i]=x;
}

var funcfill = func(v,cb) {
    if(typeof(v)=="scalar")
        v = setsize([],v);
    forindex(var i;v) v[i]=cb(i);
    return v;
}

var map = func(v,cb) {
    forindex(var i;v) v[i]=cb(v[i]);
}

var peak = func(v) {
  var x = v[0];
  forindex(var i;v) if(v[i]>x) x=v[i];
  return x;
}

var normalize = func(v, max=1) {
  v = v~[];
  max = max / peak(v);
  forindex(var i;v) v[i] *= max;
}

var sum = func(v) {
    var s=0;
    foreach(var x;v) s+=x;
    return s;
}

var normsum = func(v,n=1) {
    v = v~[];
    n = sum(v)/n;
    forindex(var i;v) v[i] /= n;
}

var delete = func(v,n) {
    subvec(v,0,n) ~ subvec(v,n+1);
}

var split = func(v,n) { [ subvec(v,0,n), subvec(v,n) ]; }

var rotate = func(v,n) {
    if(n==0) return v;
    n = -n;
    if(n<0) n=size(v)+n;
    var a = subvec(v,0,n);
    var b = subvec(v,n);
    return b ~ a;
}

var scramble = func(v,n=nil) {
    var l=size(v);
    var i=n!=nil?n:l;
    v = v~[];
    while(i) {
        i -= 1;
        var i1=0;
        var i2=0;
        
        while(i1==i2) {
            i1=math.round(math.rand()*(l-1));
            i2=math.round(math.rand()*(l-1));
        }

        var t=v[i1];
        v[i1]=v[i2];
        v[i2]=t;
        
    }
    return v;
}

var randperm = func(v) {
    v = v~[];
    var n = size(v)-1;
    for(var i=0;i<n;i+=1) {
        i2=i+math.round(math.rand()*(n-i));

        var t=v[i2];
        v[i2]=v[i];
        v[i]=t;
    }
    return v;
}

var ipol = func(v,i) {
    var a = v[math.mod(i,size(v))];
    var b = v[math.mod((i+1),size(v))];
    var i = i - int(i);
    return a+((b-a)*i);
}

# resample so that the new vector starts and
# stops with the same values as original
var resample = func(v,i,type=0) {
    var sz1 = size(v);
    var sz2 = int(i);
    if(sz1==sz2) return v~[]; # just copy
    var v2 = setsize([],sz2);
    var r = type==0 and sz1>1 and sz2>1?(sz1-1)/(sz2-1):sz1/sz2;
    for(var i=0; i<sz2; i+=1)
        v2[i] = ipol(v,i*r);
    return v2;
}

var find = func(v,x) {
    forindex(var i;v) if(x==v[i]) return i;
    return -1;
}

var multicycle = func(fn,vecs...) {
    var cnt = setsize([],size(vecs));
    var vals = setsize([],size(vecs));
    forindex(var i;cnt) { cnt[i]=0; }
    var res = 0;
    #var x=1;
    while(!res) {
        #var sync=0;
        forindex(var i;cnt) {
            vals[i] = vecs[i][cnt[i]];
            #sync += cnt[i];
            cnt[i] += 1;
            if(cnt[i]>=size(vecs[i])) { cnt[i]=0; }
        }
        #if(sync==0) print("SYNC at ",x," iterations\n");
        res = call(fn,vals);
        #x += 1;
        #print("callback returned ",res,"\n");
    }
    return res;
}

#TODO: function to calculate when multiple cycles will synch...
var calcmultisync = func {
    var x = 1;
    while(1) {
        var found=1;
        foreach(var a;arg) {
            if(x/a != int(x/a)) { found=0; continue; }
        }
        x += 1;
        if(found) return x;
    }
    return 0;
}

# delete all references to x in vector v
var delete = func(v,x) {
    forindex(i; v) {
        if(x == v[i]) {
            v[i] = v[-1];
            pop(v);
        }
    }
}
